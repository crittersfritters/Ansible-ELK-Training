#!/usr/bin/env bash

check_required_paths() {
  section "Required answer-sheet files"
  local relative missing=0
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    if [[ -e "$PROJECT_ROOT/$relative" ]]; then
      pass "$relative exists"
    else
      fail "$relative is missing"
      missing=$((missing + 1))
    fi
  done <<< "$REQUIRED_PATHS"

  if (( missing == 0 )); then
    note "All required reference files are present."
  fi
}

check_yaml_syntax() {
  section "YAML syntax"
  if ! have_command python3; then
    skip "Python 3 is unavailable; YAML syntax was not parsed"
    return
  fi
  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "PyYAML is unavailable; install it to enable repository-wide YAML parsing"
    return
  fi

  local file output found=0
  while IFS= read -r -d '' file; do
    found=1
    if IFS= read -r first_line < "$file" && [[ "$first_line" == '$ANSIBLE_VAULT;'* ]]; then
      pass "Ansible Vault payload detected: ${file#"$PROJECT_ROOT/"}"
      continue
    fi
    if output=$(python3 - "$file" <<'PY'
import pathlib
import sys
import yaml

path = pathlib.Path(sys.argv[1])
with path.open("r", encoding="utf-8") as stream:
    list(yaml.compose_all(stream))
PY
    ); then
      pass "YAML parses: ${file#"$PROJECT_ROOT/"}"
    else
      fail "YAML does not parse: ${file#"$PROJECT_ROOT/"}"
      show_command_failure "$output"
    fi
  done < <(
    find "$PROJECT_ROOT" \
      -path "$PROJECT_ROOT/.git" -prune -o \
      -path "$PROJECT_ROOT/validation" -prune -o \
      -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 | sort -z
  )
  if (( found == 0 )); then
    fail "No YAML files were found"
  fi
}

check_reference_templates() {
  section "Rendered Compose and Filebeat templates"
  if ! have_command python3 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "Python 3 with PyYAML is unavailable; Compose templates were not rendered"
    return
  fi

  local temp_dir output file compose_count=0 filebeat_count=0
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/mini-manticore-compose.XXXXXX") || {
    fail "Unable to create a temporary directory for rendered Compose files"
    return
  }
  if output=$(python3 "$VALIDATION_DIR/lib/render_compose.py" "$PROJECT_ROOT" "$temp_dir" 2>&1); then
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      case "${file##*/}" in
        compose-*)
          compose_count=$((compose_count + 1))
          pass "Compose template renders as YAML: ${file##*/}"
          ;;
        filebeat-*)
          filebeat_count=$((filebeat_count + 1))
          pass "Filebeat template renders as YAML: ${file##*/}"
          ;;
        *)
          fail "Renderer produced an unexpected file: ${file##*/}"
          ;;
      esac
    done <<< "$output"
  else
    fail "One or more Compose templates could not be rendered"
    show_command_failure "$output"
    rm -rf -- "$temp_dir"
    return
  fi

  if (( compose_count != 7 )); then
    fail "Expected seven rendered Compose templates; renderer produced $compose_count"
  fi
  if (( filebeat_count != 2 )); then
    fail "Expected two rendered Filebeat templates; renderer produced $filebeat_count"
  fi

  set_docker_command
  if have_command "${DOCKER_PARTS[0]}" && docker_compose_available; then
    for file in "$temp_dir"/compose-*.yml; do
      if output=$("${DOCKER_PARTS[@]}" compose -f "$file" config --quiet 2>&1); then
        pass "Docker Compose accepts rendered template: ${file##*/}"
      else
        fail "Docker Compose rejects rendered template: ${file##*/}"
        show_command_failure "$output"
      fi
    done
  else
    skip "Docker Compose is unavailable; rendered YAML was not Compose-validated"
  fi
  rm -rf -- "$temp_dir"
}

set_docker_command() {
  read -r -a DOCKER_PARTS <<< "$DOCKER_COMMAND"
  if (( ${#DOCKER_PARTS[@]} == 0 )); then
    DOCKER_PARTS=(docker)
  fi
}

docker_compose_available() {
  "${DOCKER_PARTS[@]}" compose version >/dev/null 2>&1
}

check_concrete_compose_files() {
  section "Concrete Compose configuration"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}"; then
    skip "${DOCKER_PARTS[0]} is unavailable; Compose rendering checks were skipped"
    return
  fi
  if ! docker_compose_available; then
    skip "The Docker Compose plugin is unavailable; Compose rendering checks were skipped"
    return
  fi

  local file output found=0
  while IFS= read -r -d '' file; do
    found=1
    if output=$("${DOCKER_PARTS[@]}" compose -f "$file" config --quiet 2>&1); then
      pass "Compose renders: ${file#"$PROJECT_ROOT/"}"
    else
      fail "Compose does not render: ${file#"$PROJECT_ROOT/"}"
      show_command_failure "$output"
    fi
  done < <(
    find "$PROJECT_ROOT" \
      -path "$PROJECT_ROOT/.git" -prune -o \
      -path "$PROJECT_ROOT/validation" -prune -o \
      -type f \( \
        -name 'compose.yml' -o -name 'compose.yaml' -o \
        -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
      \) -print0 | sort -z
  )

  if (( found == 0 )); then
    skip "No concrete Compose files are committed; templates are checked after deployment by the runtime suite"
  fi
}

check_ansible_inventory() {
  section "Ansible inventory"
  local inventory="$PROJECT_ROOT/$INVENTORY_FILE"
  if [[ ! -f "$inventory" ]]; then
    fail "$INVENTORY_FILE is unavailable for inventory validation"
    return
  fi
  if ! have_command ansible-inventory; then
    skip "ansible-inventory is unavailable; inventory semantics were not evaluated"
    return
  fi
  if ! have_command python3; then
    skip "Python 3 is unavailable; Ansible inventory JSON could not be evaluated"
    return
  fi

  local inventory_json output
  if ! inventory_json=$(ansible-inventory -i "$inventory" --list); then
    fail "Ansible could not parse $INVENTORY_FILE"
    show_command_failure "$inventory_json"
    return
  fi
  pass "Ansible parses $INVENTORY_FILE"

  if output=$(python3 - "$INVENTORY_HOST" $INVENTORY_GROUPS 3<<< "$inventory_json" <<'PY'
import json
import os
import sys

expected_host = sys.argv[1]
groups = sys.argv[2:]
with os.fdopen(3) as stream:
    data = json.load(stream)
problems = []
for group in groups:
    hosts = data.get(group, {}).get("hosts", [])
    if hosts != [expected_host]:
        problems.append(f"{group}: expected only {expected_host!r}, got {hosts!r}")
hostvars = data.get("_meta", {}).get("hostvars", {})
if expected_host not in hostvars:
    problems.append(f"{expected_host!r} is absent from _meta.hostvars")
else:
    variables = hostvars[expected_host]
    if variables.get("ansible_connection") != "ssh":
        problems.append("ansible_connection must be ssh")
    if variables.get("ansible_user") != "ansible":
        problems.append("ansible_user must be ansible")
    if "ansible_host" in variables:
        problems.append("ansible_host must be absent so mini-manticore.local is resolved normally")
if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  ); then
    pass "The host-preparation group and all six service groups contain only $INVENTORY_HOST"
  else
    fail "Inventory does not implement the one-host localhost model"
    show_command_failure "$output"
  fi
}

check_ansible_syntax() {
  section "Ansible playbook syntax"
  if ! have_command ansible-playbook; then
    skip "ansible-playbook is unavailable; syntax-check was skipped"
    return
  fi
  local inventory="$PROJECT_ROOT/$INVENTORY_FILE"
  local playbook="$PROJECT_ROOT/$MAIN_PLAYBOOK"
  if [[ ! -f "$inventory" || ! -f "$playbook" ]]; then
    fail "Inventory or main playbook is missing; Ansible syntax-check cannot run"
    return
  fi

  local output
  if output=$(cd "$PROJECT_ROOT" && \
    ANSIBLE_NOCOWS=1 ansible-playbook -i "$inventory" --syntax-check "$playbook" 2>&1); then
    pass "Ansible syntax-check passes for $MAIN_PLAYBOOK"
  else
    fail "Ansible syntax-check fails for $MAIN_PLAYBOOK"
    show_command_failure "$output"
  fi
}

check_configuration_assets() {
  section "Configuration assets"
  local port_router="$PROJECT_ROOT/roles/port_router/files/pipeline/logstash_port-router.conf"
  local grok_consumer="$PROJECT_ROOT/roles/logstash_pipeline/files/pipeline/grok_pipeline.conf"
  local zeek_filebeat="$PROJECT_ROOT/roles/filebeat_zeek/templates/filebeat.yml.j2"
  local suricata_filebeat="$PROJECT_ROOT/roles/filebeat_suricata/templates/filebeat.yml.j2"
  local ci_file="$PROJECT_ROOT/.gitlab-ci.yml"
  local child_ci_file="$PROJECT_ROOT/.gitlab/deploy.yml"

  if [[ -s "$port_router" ]] && grep -q 'grok[[:space:]]*{' "$port_router"; then
    pass "Port-router configuration contains Grok parsing"
  else
    fail "Port-router Grok configuration is absent or empty"
  fi
  if grep -q 'codec[[:space:]]*=>[[:space:]]*line' "$port_router"; then
    pass "Port-router TCP input uses newline-delimited framing"
  else
    fail "Port-router TCP input does not use the line codec"
  fi
  if grep -R -E -q 'bootstrap_servers[[:space:]]*=>[[:space:]]*\[' \
    "$PROJECT_ROOT/roles/logstash_pipeline/files/pipeline" \
    "$PROJECT_ROOT/roles/port_router/files/pipeline"; then
    fail "A Logstash Kafka plugin uses an invalid array-valued bootstrap_servers setting"
  else
    pass "Logstash Kafka bootstrap_servers settings use the required string form"
  fi
  if [[ -s "$grok_consumer" ]] && grep -q 'kafka[[:space:]]*{' "$grok_consumer"; then
    pass "Mission consumer configuration contains a Kafka input"
  else
    fail "Mission Kafka consumer configuration is absent or empty"
  fi
  if [[ -s "$zeek_filebeat" ]]; then
    pass "Zeek Filebeat configuration is nonempty"
  else
    fail "Zeek Filebeat configuration is absent or empty"
  fi
  if [[ -s "$suricata_filebeat" ]]; then
    pass "Suricata Filebeat configuration is nonempty"
  else
    fail "Suricata Filebeat configuration is absent or empty"
  fi
  if [[ -s "$ci_file" ]]; then
    pass "Answer-sheet GitLab pipeline reference is nonempty"
  else
    fail "GitLab pipeline reference is absent or empty"
  fi
  if [[ -s "$child_ci_file" ]] \
    && grep -q 'mini-manticore-local' "$child_ci_file" \
    && grep -q 'CI_COMMIT_REF_PROTECTED' "$ci_file"; then
    pass "GitLab deployment requires the intended runner and protected refs"
  else
    fail "GitLab deployment runner or protected-ref guard is missing"
  fi
  if grep -Eq '^[[:space:]]*host_key_checking[[:space:]]*=[[:space:]]*[Ff]alse' \
    "$PROJECT_ROOT/ansible.cfg"; then
    fail "Ansible host-key checking is disabled"
  else
    pass "Ansible does not disable SSH host-key checking"
  fi
  local sample missing_sample=0
  for sample in pan-simple pan-full unmatched date-failure; do
    if [[ -s "$PROJECT_ROOT/samples/mission/$sample.log" ]]; then
      pass "Mission sample is present: $sample.log"
    else
      fail "Mission sample is missing: samples/mission/$sample.log"
      missing_sample=1
    fi
  done
  if (( missing_sample == 0 )) && [[ -s "$PROJECT_ROOT/samples/mission/expected-outcomes.yml" ]]; then
    pass "Canonical mission outcome assertions are present"
  elif [[ ! -s "$PROJECT_ROOT/samples/mission/expected-outcomes.yml" ]]; then
    fail "Canonical mission outcome assertions are missing"
  fi
}

check_documentation_integrity() {
  section "Documentation integrity"
  if ! have_command python3; then
    skip "Python 3 is unavailable; local Markdown links were not checked"
    return
  fi

  local output
  if output=$(python3 - "$PROJECT_ROOT" <<'PY'
import pathlib
import re
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1]).resolve()
problems = []
link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
for document in sorted(root.rglob("*.md")):
    if ".git" in document.parts:
        continue
    text = document.read_text(encoding="utf-8")
    for raw in link_pattern.findall(text):
        target = raw.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        path_text = urllib.parse.unquote(target.split("#", 1)[0])
        destination = (document.parent / path_text).resolve()
        try:
            destination.relative_to(root)
        except ValueError:
            problems.append(f"{document.relative_to(root)}: link escapes repository: {target}")
            continue
        if not destination.exists():
            problems.append(f"{document.relative_to(root)}: missing target: {target}")

if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  ); then
    pass "All local Markdown links resolve inside the repository"
  else
    fail "One or more local Markdown links are broken"
    show_command_failure "$output"
  fi
}

check_idempotence_evidence() {
  section "Ansible idempotence evidence"
  local evidence
  evidence=$(absolute_from_project "$IDEMPOTENCE_EVIDENCE")
  if [[ ! -f "$evidence" ]]; then
    skip "No second-run transcript at ${evidence#"$PROJECT_ROOT/"}; see validation/README.md"
    return
  fi

  local line found=0 bad=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[^[:space:]].*ok=[0-9]+[[:space:]]+changed=([0-9]+)[[:space:]]+unreachable=([0-9]+)[[:space:]]+failed=([0-9]+) ]]; then
      found=1
      if [[ "${BASH_REMATCH[1]}" == 0 && "${BASH_REMATCH[2]}" == 0 && "${BASH_REMATCH[3]}" == 0 ]]; then
        pass "Idempotent recap: $line"
      else
        fail "Non-idempotent or unsuccessful recap: $line"
        bad=1
      fi
    fi
  done < "$evidence"

  if (( found == 0 )); then
    fail "The idempotence transcript contains no recognizable PLAY RECAP host lines"
  elif (( bad == 0 )); then
    note "Every captured second-run host reports changed=0, unreachable=0, failed=0."
  fi
}

run_static_checks() {
  check_required_paths
  check_yaml_syntax
  check_reference_templates
  check_concrete_compose_files
  check_ansible_inventory
  check_ansible_syntax
  check_configuration_assets
  check_documentation_integrity
  check_idempotence_evidence
}
