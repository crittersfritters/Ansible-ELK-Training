#!/usr/bin/env bash

check_host_aliases() {
  section "Local host aliases"
  local alias line resolved
  for alias in $HOST_ALIASES; do
    if line=$(awk -v wanted="$alias" -v address="$EXPECTED_ALIAS_ADDRESS" '
      $0 !~ /^[[:space:]]*#/ && $1 == address {
        for (i = 2; i <= NF; i++) if ($i == wanted) { print; exit }
      }
    ' /etc/hosts 2>/dev/null) && [[ -n "$line" ]]; then
      pass "$alias is explicitly mapped to $EXPECTED_ALIAS_ADDRESS in /etc/hosts"
    else
      fail "$alias is not explicitly mapped to $EXPECTED_ALIAS_ADDRESS in /etc/hosts"
    fi

    if have_command getent; then
      resolved=$(getent ahostsv4 "$alias" 2>/dev/null | awk 'NR == 1 {print $1}')
      if [[ "$resolved" == "$EXPECTED_ALIAS_ADDRESS" ]]; then
        pass "$alias resolves to $EXPECTED_ALIAS_ADDRESS"
      elif [[ -n "$resolved" ]]; then
        fail "$alias resolves to $resolved instead of $EXPECTED_ALIAS_ADDRESS"
      else
        fail "$alias does not resolve"
      fi
    else
      skip "getent is unavailable; resolver result for $alias was not checked"
    fi
  done
}

check_deployed_compose() {
  section "Rendered Compose projects"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}" || ! docker_compose_available; then
    skip "Docker Compose is unavailable; rendered Compose files were not checked"
    return
  fi

  local component directory candidate file output
  for component in $DEPLOYED_COMPOSE_DIRS; do
    directory="$DEPLOY_ROOT/$component"
    file=""
    for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
      if [[ -f "$directory/$candidate" ]]; then
        file="$directory/$candidate"
        break
      fi
    done
    if [[ -z "$file" ]]; then
      fail "No rendered Compose file exists under $directory"
      continue
    fi
    if output=$("${DOCKER_PARTS[@]}" compose -f "$file" config --quiet 2>&1); then
      pass "Rendered Compose configuration is valid: $file"
    else
      fail "Rendered Compose configuration is invalid: $file"
      show_command_failure "$output"
    fi
  done
}

inspect_container_state() {
  local container="$1" expected="$2" output status health exit_code
  if ! output=$("${DOCKER_PARTS[@]}" inspect \
    --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.State.ExitCode}}' \
    "$container" 2>&1); then
    fail "Container $container is absent or cannot be inspected"
    show_command_failure "$output"
    return
  fi
  IFS='|' read -r status health exit_code <<< "$output"

  if [[ "$expected" == healthy ]]; then
    if [[ "$status" != running ]]; then
      fail "Container $container is $status; expected running"
    elif [[ "$health" != healthy ]]; then
      fail "Container $container is running with health=$health; expected healthy"
    else
      pass "Container $container is running and healthy"
    fi
  elif [[ "$expected" == running ]]; then
    if [[ "$status" == running ]]; then
      pass "Container $container is running (health=$health)"
    else
      fail "Container $container is $status; expected running"
    fi
  else
    if [[ "$status" == exited && "$exit_code" == 0 ]]; then
      pass "One-shot container $container completed successfully"
    else
      fail "One-shot container $container has status=$status exit=$exit_code; expected exited/0"
    fi
  fi
}

check_containers() {
  section "Container states"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}"; then
    skip "${DOCKER_PARTS[0]} is unavailable; container states were not checked"
    return
  fi
  if ! "${DOCKER_PARTS[@]}" info >/dev/null 2>&1; then
    fail "Docker is unavailable or the current account cannot access the daemon"
    return
  fi

  local container
  for container in $HEALTHY_CONTAINERS; do
    inspect_container_state "$container" healthy
  done
  for container in $RUNNING_CONTAINERS; do
    inspect_container_state "$container" running
  done
  for container in $COMPLETED_CONTAINERS; do
    inspect_container_state "$container" completed
  done
}

check_gitlab_bindings() {
  section "GitLab runtime contract"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}" || ! have_command python3; then
    skip "Docker and Python 3 are required for GitLab runtime checks"
    return
  fi

  local actual_image bindings metadata output
  if actual_image=$(
    "${DOCKER_PARTS[@]}" inspect --format '{{.Config.Image}}' \
      "$GITLAB_CONTAINER" 2>&1
  ); then
    if [[ "$actual_image" == "$GITLAB_IMAGE" ]]; then
      pass "GitLab uses the pinned image $GITLAB_IMAGE"
    else
      fail "GitLab image is $actual_image; expected $GITLAB_IMAGE"
    fi
  else
    fail "GitLab image could not be inspected"
    show_command_failure "$actual_image"
  fi

  if ! metadata=$("${DOCKER_PARTS[@]}" inspect \
    --format '{{json .}}' "$GITLAB_CONTAINER" 2>&1); then
    fail "GitLab runtime metadata could not be inspected"
    show_command_failure "$metadata"
    return
  fi
  if output=$(python3 - \
    "$GITLAB_COMPOSE_PROJECT" \
    "$GITLAB_COMPOSE_SERVICE" \
    "$GITLAB_COMPOSE_WORKDIR" \
    "$GITLAB_COMPOSE_FILE" \
    "$GITLAB_EXTERNAL_URL" \
    "$GITLAB_SSH_PORT" \
    $GITLAB_MOUNT_BINDINGS \
    3<<< "$metadata" <<'PY'
import json
import os
import sys
from collections import Counter

with os.fdopen(3) as stream:
    container = json.load(stream)

(
    expected_project,
    expected_service,
    expected_workdir,
    expected_compose_file,
    expected_external_url,
    expected_ssh_port,
) = sys.argv[1:7]
expected_mount_specs = sys.argv[7:]
problems = []

labels = container.get("Config", {}).get("Labels") or {}
expected_labels = {
    "com.docker.compose.project": expected_project,
    "com.docker.compose.service": expected_service,
    "com.docker.compose.project.working_dir": expected_workdir,
    "com.docker.compose.project.config_files": expected_compose_file,
}
for label, expected in expected_labels.items():
    actual = labels.get(label)
    if actual != expected:
        problems.append(f"label {label!r}: expected {expected!r}, got {actual!r}")

expected_mounts = Counter(
    ("bind", source, destination, True)
    for source, destination in (
        spec.split(":", 1) for spec in expected_mount_specs
    )
)
actual_mounts = Counter(
    (
        mount.get("Type"),
        mount.get("Source"),
        mount.get("Destination"),
        mount.get("RW"),
    )
    for mount in container.get("Mounts", [])
)
if actual_mounts != expected_mounts:
    problems.append(
        f"mounts: expected {sorted(expected_mounts.elements())!r}, "
        f"got {sorted(actual_mounts.elements())!r}"
    )

environment = container.get("Config", {}).get("Env") or []
prefix = "GITLAB_OMNIBUS_CONFIG="
omnibus_values = [value[len(prefix):] for value in environment if value.startswith(prefix)]
if len(omnibus_values) != 1:
    problems.append(
        f"expected one GITLAB_OMNIBUS_CONFIG value, got {len(omnibus_values)}"
    )
else:
    actual_lines = Counter(
        statement.strip()
        for line in omnibus_values[0].splitlines()
        for statement in line.split(";")
        if statement.strip()
    )
    expected_lines = Counter({
        f"external_url '{expected_external_url}'",
        f"gitlab_rails['gitlab_shell_ssh_port'] = {expected_ssh_port}",
    })
    if actual_lines != expected_lines:
        problems.append(
            "GITLAB_OMNIBUS_CONFIG: expected "
            f"{sorted(expected_lines.elements())!r}, "
            f"got {sorted(actual_lines.elements())!r}"
        )

if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  ); then
    pass "GitLab uses the required Compose project, working directory, configuration, and mounts"
  else
    fail "GitLab runtime ownership or persistence diverges from the course contract"
    show_command_failure "$output"
  fi

  if ! bindings=$("${DOCKER_PARTS[@]}" inspect \
    --format '{{json .NetworkSettings.Ports}}' "$GITLAB_CONTAINER" 2>&1); then
    fail "GitLab port bindings could not be inspected"
    show_command_failure "$bindings"
    return
  fi
  if output=$(python3 - $GITLAB_PORT_BINDINGS 3<<< "$bindings" <<'PY'
import json
import os
import sys
from collections import Counter

with os.fdopen(3) as stream:
    ports = json.load(stream)

expected = Counter(tuple(spec.split(":", 2)) for spec in sys.argv[1:])
actual = Counter(
    (container_port, entry.get("HostIp"), entry.get("HostPort"))
    for container_port, entries in ports.items()
    for entry in (entries or [])
)

if actual != expected:
    missing = expected - actual
    unexpected = actual - expected
    if missing:
        print("missing bindings:")
        for binding, count in sorted(missing.items()):
            print(f"  {binding!r} x{count}")
    if unexpected:
        print("unexpected bindings:")
        for binding, count in sorted(unexpected.items()):
            print(f"  {binding!r} x{count}")
    raise SystemExit(1)
PY
  ); then
    pass "GitLab has exactly the required HTTP, port 443, and SSH loopback publications"
  else
    fail "GitLab does not implement the required loopback-only port bindings"
    show_command_failure "$output"
  fi
}

check_http_endpoint() {
  local label="$1" url="$2" output
  if output=$(curl -fsS --max-time 8 "$url" 2>&1); then
    pass "$label responds: $url"
  else
    fail "$label does not respond: $url"
    show_command_failure "$output"
  fi
}

check_service_endpoints() {
  section "Service health endpoints"
  if ! have_command curl; then
    skip "curl is unavailable; HTTP health endpoints were not checked"
    return
  fi
  if ! have_command python3; then
    skip "Python 3 is unavailable; JSON health responses were not evaluated"
    return
  fi
  local es_health es_output
  if es_health=$(curl -fsS --max-time 8 "$ES_URL/_cluster/health?wait_for_status=yellow&timeout=5s" 2>&1); then
    if es_output=$(python3 - 3<<< "$es_health" <<'PY'
import json
import os

with os.fdopen(3) as stream:
    health = json.load(stream)
status = health.get("status")
if health.get("timed_out") is True or status not in {"yellow", "green"}:
    raise SystemExit(f"status={status!r} timed_out={health.get('timed_out')!r}")
print(f"status={status} timed_out={health.get('timed_out', False)}")
PY
    ); then
      pass "Elasticsearch cluster health is acceptable ($es_output)"
    else
      fail "Elasticsearch cluster is not yellow or green"
      show_command_failure "$es_output"
    fi
  else
    fail "Elasticsearch cluster health does not respond: $ES_URL"
    show_command_failure "$es_health"
  fi
  local kibana_status kibana_output
  if kibana_status=$(curl -fsS --max-time 8 "$KIBANA_URL/api/status" 2>&1); then
    if kibana_output=$(python3 - 3<<< "$kibana_status" <<'PY'
import json
import os

with os.fdopen(3) as stream:
    status = json.load(stream)
level = status.get("status", {}).get("overall", {}).get("level")
if level != "available":
    raise SystemExit(f"overall level={level!r}")
print(f"overall level={level}")
PY
    ); then
      pass "Kibana reports itself available ($kibana_output)"
    else
      fail "Kibana responds but is not available"
      show_command_failure "$kibana_output"
    fi
  else
    fail "Kibana status does not respond: $KIBANA_URL/api/status"
    show_command_failure "$kibana_status"
  fi
  check_http_endpoint "Kafka UI" "$KAFKA_UI_URL/"
  check_http_endpoint "GitLab sign-in page" "${GITLAB_URL%/}/users/sign_in"

  local pipeline
  for pipeline in $LOGSTASH_PIPELINE_IDS; do
    check_http_endpoint "Processing Logstash pipeline $pipeline" "$LOGSTASH_PIPELINE_URL/_node/pipelines/$pipeline"
  done
  check_http_endpoint "Port-router Logstash pipeline $PORT_ROUTER_PIPELINE_ID" "$PORT_ROUTER_URL/_node/pipelines/$PORT_ROUTER_PIPELINE_ID"
}

check_loopback_bindings() {
  section "Loopback-only listener policy"
  if ! have_command ss; then
    skip "ss is unavailable; listener bind addresses were not checked"
    return
  fi

  local port output address found bad
  for port in $LOOPBACK_TCP_PORTS; do
    output=$(ss -H -ltn 2>/dev/null | awk -v port="$port" '$4 ~ (":" port "$") {print $4}')
    if [[ -z "$output" ]]; then
      fail "No TCP listener was found on expected port $port"
      continue
    fi
    found=0
    bad=0
    while IFS= read -r address; do
      [[ -n "$address" ]] || continue
      found=1
      case "$address" in
        127.0.0.1:"$port"|\[::1\]:"$port") ;;
        *) bad=1 ;;
      esac
    done <<< "$output"
    if (( found == 1 && bad == 0 )); then
      pass "TCP/$port listens only on loopback"
    else
      fail "TCP/$port has a non-loopback listener: ${output//$'\n'/, }"
    fi
  done
}

check_sensor_logs() {
  section "Sensor source logs"
  if [[ -d "$ZEEK_LOG_PATH" ]] && find "$ZEEK_LOG_PATH" -maxdepth 1 -type f -size +0c -print -quit 2>/dev/null | grep -q .; then
    pass "Zeek has at least one nonempty current log under $ZEEK_LOG_PATH"
  elif [[ -f "$ZEEK_LOG_PATH" && -s "$ZEEK_LOG_PATH" ]]; then
    pass "Zeek source log is nonempty: $ZEEK_LOG_PATH"
  else
    fail "No nonempty Zeek source log is visible at $ZEEK_LOG_PATH"
  fi

  if [[ -f "$SURICATA_LOG_PATH" && -s "$SURICATA_LOG_PATH" ]]; then
    pass "Suricata source log is nonempty: $SURICATA_LOG_PATH"
  else
    fail "No nonempty Suricata source log is visible at $SURICATA_LOG_PATH"
  fi
}

check_kafka_topics() {
  section "Kafka topics"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}"; then
    skip "${DOCKER_PARTS[0]} is unavailable; Kafka topics were not checked"
    return
  fi

  local output
  if ! output=$("${DOCKER_PARTS[@]}" exec "$KAFKA_CONTAINER" \
    /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" --list 2>&1); then
    fail "Kafka topic listing failed"
    show_command_failure "$output"
    return
  fi

  local topic
  for topic in $KAFKA_TOPICS; do
    if grep -Fxq "$topic" <<< "$output"; then
      pass "Kafka topic exists: $topic"
    else
      fail "Kafka topic is missing: $topic"
    fi
  done
}

check_elastic_contract() {
  section "Elasticsearch indices, aliases, and templates"
  if ! have_command curl; then
    skip "curl is unavailable; Elasticsearch objects were not checked"
    return
  fi
  if ! have_command python3; then
    skip "Python 3 is unavailable; Elasticsearch responses were not evaluated"
    return
  fi

  local output pair index alias_name alias_json mapping_json
  for pair in $ELASTIC_INDEX_ALIAS_PAIRS; do
    index=${pair%%:*}
    alias_name=${pair#*:}

    if curl -fsS --head --max-time 8 "$ES_URL/$index" >/dev/null 2>&1; then
      pass "Backing index exists: $index"
    else
      fail "Backing index is missing: $index"
    fi

    if mapping_json=$(curl -fsS --max-time 8 "$ES_URL/$index/_mapping" 2>&1); then
      if output=$(python3 - "$index" 3<<< "$mapping_json" <<'PY'
import json
import os
import sys

index = sys.argv[1]
with os.fdopen(3) as stream:
    data = json.load(stream)
properties = data.get(index, {}).get("mappings", {}).get("properties", {})
checks = {
    "@timestamp": properties.get("@timestamp", {}).get("type"),
    "event.original": properties.get("event", {}).get("properties", {}).get("original", {}).get("type"),
    "source.ip": properties.get("source", {}).get("properties", {}).get("ip", {}).get("type"),
    "_parser.id": properties.get("_parser", {}).get("properties", {}).get("id", {}).get("type"),
    "rule.name": properties.get("rule", {}).get("properties", {}).get("name", {}).get("type"),
}
expected = {"@timestamp": "date", "event.original": "wildcard", "source.ip": "ip", "_parser.id": "keyword", "rule.name": "keyword"}
bad = [f"{field}={actual!r}" for field, actual in checks.items() if actual != expected[field]]
if bad:
    raise SystemExit("unexpected mappings: " + ", ".join(bad))
PY
      ); then
        pass "Backing index $index has the current core mappings"
      else
        fail "Backing index mapping is stale or incorrect: $index"
        show_command_failure "$output"
      fi
    else
      fail "Backing index mapping is unreadable: $index"
      show_command_failure "$mapping_json"
    fi

    if alias_json=$(curl -fsS --max-time 8 "$ES_URL/_alias/$alias_name" 2>&1); then
      if output=$(python3 - "$index" "$alias_name" 3<<< "$alias_json" <<'PY'
import json
import os
import sys

expected_index, alias = sys.argv[1:]
with os.fdopen(3) as stream:
    data = json.load(stream)
entry = data.get(expected_index, {}).get("aliases", {}).get(alias)
if entry is None:
    raise SystemExit(f"{alias!r} does not point to {expected_index!r}")
if entry.get("is_write_index") is not True:
    raise SystemExit(f"{alias!r} is not the explicit write alias for {expected_index!r}")
PY
      ); then
        pass "Write alias $alias_name points to $index"
      else
        fail "Alias contract is incorrect for $alias_name"
        show_command_failure "$output"
      fi
    else
      fail "Alias is missing or unreadable: $alias_name"
      show_command_failure "$alias_json"
    fi

  done

  local spec template_name expected_pattern template_json
  for spec in $ELASTIC_TEMPLATE_SPECS; do
    template_name=${spec%%:*}
    expected_pattern=${spec#*:}
    if ! template_json=$(curl -fsS --max-time 8 \
      "$ES_URL/_index_template/$template_name" 2>&1); then
      fail "Composable index template is missing: $template_name"
      show_command_failure "$template_json"
      continue
    fi
    if output=$(python3 - "$template_name" "$expected_pattern" 3<<< "$template_json" <<'PY'
import json
import os
import sys

name, pattern = sys.argv[1:]
with os.fdopen(3) as stream:
    data = json.load(stream)
items = [item for item in data.get("index_templates", []) if item.get("name") == name]
if len(items) != 1:
    raise SystemExit(f"expected one template named {name!r}, got {len(items)}")
definition = items[0].get("index_template", {})
if pattern not in definition.get("index_patterns", []):
    raise SystemExit(f"expected pattern {pattern!r}")
properties = definition.get("template", {}).get("mappings", {}).get("properties", {})
checks = {
    "@timestamp": properties.get("@timestamp", {}).get("type"),
    "event.original": properties.get("event", {}).get("properties", {}).get("original", {}).get("type"),
    "source.ip": properties.get("source", {}).get("properties", {}).get("ip", {}).get("type"),
    "_parser.id": properties.get("_parser", {}).get("properties", {}).get("id", {}).get("type"),
    "rule.name": properties.get("rule", {}).get("properties", {}).get("name", {}).get("type"),
}
expected = {"@timestamp": "date", "event.original": "wildcard", "source.ip": "ip", "_parser.id": "keyword", "rule.name": "keyword"}
bad = [f"{field}={actual!r}" for field, actual in checks.items() if actual != expected[field]]
if bad:
    raise SystemExit("unexpected mappings: " + ", ".join(bad))
PY
    ); then
      pass "Template $template_name has the required pattern and core mappings"
    else
      fail "Template contract is incorrect: $template_name"
      show_command_failure "$output"
    fi
  done
}

check_sensor_outcomes() {
  section "Recent Zeek and Suricata indexed outcomes"
  if ! have_command curl || ! have_command python3; then
    skip "curl and Python 3 are required for sensor outcome checks"
    return
  fi

  local spec alias_name module_name pipeline_name required_fields request response output
  for spec in \
    'active-zeek|zeek|zeek_pipeline|ts,id.orig_h,id.resp_h' \
    'active-suricata|suricata|suricata_pipeline|timestamp,src_ip,dest_ip'; do
    IFS='|' read -r alias_name module_name pipeline_name required_fields <<< "$spec"
    request=$(python3 - "$SENSOR_MAX_AGE" <<'PY'
import json
import sys

print(json.dumps({
    "size": 100,
    "sort": [{"@timestamp": {"order": "desc"}}],
    "query": {"range": {"@timestamp": {"gte": f"now-{sys.argv[1]}"}}},
}))
PY
    )
    if ! response=$(curl -fsS --max-time 8 \
      -H 'Content-Type: application/json' \
      -X POST "$ES_URL/$alias_name/_search" \
      --data-binary "$request" 2>&1); then
      fail "Recent $module_name documents could not be queried through $alias_name"
      show_command_failure "$response"
      continue
    fi
    if output=$(python3 - "$module_name" "$pipeline_name" "$required_fields" 3<<< "$response" <<'PY'
import json
import os
import sys

module, pipeline, required_csv = sys.argv[1:]
with os.fdopen(3) as stream:
    data = json.load(stream)

def nested(source, dotted):
    value = source
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value

reasons = []
for hit in data.get("hits", {}).get("hits", []):
    source = hit.get("_source", {})
    if nested(source, "event.module") != module:
        reasons.append(f"event.module={nested(source, 'event.module')!r}")
        continue
    if source.get("logstash_pipeline") != pipeline:
        reasons.append(f"logstash_pipeline={source.get('logstash_pipeline')!r}")
        continue
    missing = [field for field in required_csv.split(",") if nested(source, field) is None]
    if missing:
        reasons.append("missing=" + ",".join(missing))
        continue
    print(f"index={hit.get('_index')} timestamp={source.get('@timestamp')}")
    raise SystemExit(0)
print("; ".join(reasons[-5:]) or "no recent documents")
raise SystemExit(1)
PY
    ); then
      pass "A recent $module_name event traversed Filebeat, Kafka, Logstash, and Elasticsearch"
      note "$output"
    else
      fail "No conforming $module_name event was indexed within $SENSOR_MAX_AGE"
      show_command_failure "$output"
    fi
  done
}

check_kibana_data_views() {
  section "Kibana data views"
  if ! have_command curl || ! have_command python3; then
    skip "curl and Python 3 are required for data-view checks"
    return
  fi

  local spec view_id expected_pattern response output
  for spec in $KIBANA_DATA_VIEW_SPECS; do
    view_id=${spec%%:*}
    expected_pattern=${spec#*:}
    if ! response=$(curl -fsS --max-time 8 \
      -H 'kbn-xsrf: mini-manticore-validation' \
      "$KIBANA_URL/api/data_views/data_view/$view_id" 2>&1); then
      fail "Kibana data view is missing: $view_id"
      show_command_failure "$response"
      continue
    fi
    if output=$(python3 - "$view_id" "$expected_pattern" 3<<< "$response" <<'PY'
import json
import os
import sys

view_id, expected_pattern = sys.argv[1:]
with os.fdopen(3) as stream:
    data = json.load(stream)
view = data.get("data_view", {})
problems = []
if view.get("id") != view_id:
    problems.append(f"id={view.get('id')!r}")
if view.get("title") != expected_pattern:
    problems.append(f"title={view.get('title')!r}")
if view.get("timeFieldName") != "@timestamp":
    problems.append(f"timeFieldName={view.get('timeFieldName')!r}")
if problems:
    raise SystemExit(", ".join(problems))
PY
    ); then
      pass "Data view $view_id targets $expected_pattern using @timestamp"
    else
      fail "Kibana data-view contract is incorrect: $view_id"
      show_command_failure "$output"
    fi
  done
}

run_native_config_tests() {
  section "Native Logstash and Filebeat configuration tests"
  if (( RUN_CONFIG_TESTS == 0 )); then
    skip "Native configuration tests were not requested; use --config-tests"
    return
  fi
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}"; then
    skip "${DOCKER_PARTS[0]} is unavailable; native configuration tests were not run"
    return
  fi

  local container output safe_name temp_path
  for container in $LOGSTASH_CONTAINERS; do
    safe_name=${container//[^[:alnum:]_-]/_}
    temp_path="/tmp/mini-manticore-validation-${safe_name}-$$"
    if output=$("${DOCKER_PARTS[@]}" exec "$container" \
      /usr/share/logstash/bin/logstash \
      --path.settings /usr/share/logstash/config \
      --path.data "$temp_path" \
      --config.test_and_exit 2>&1); then
      pass "Logstash accepts mounted configuration in $container"
    else
      fail "Logstash rejects mounted configuration in $container"
      show_command_failure "$output"
    fi
  done

  for container in $FILEBEAT_CONTAINERS; do
    if output=$("${DOCKER_PARTS[@]}" exec "$container" \
      filebeat test config -c /usr/share/filebeat/filebeat.yml 2>&1); then
      pass "Filebeat accepts mounted configuration in $container"
    else
      fail "Filebeat rejects mounted configuration in $container"
      show_command_failure "$output"
    fi
  done
}

send_tcp_sample() {
  local sample="$1"
  if have_command nc; then
    printf '%s\n' "$sample" | nc -w 3 "$MISSION_TCP_HOST" "$MISSION_TCP_PORT"
    return
  fi
  if have_command timeout; then
    timeout 4 bash -c \
      'printf "%s\n" "$1" > "/dev/tcp/$2/$3"' \
      _ "$sample" "$MISSION_TCP_HOST" "$MISSION_TCP_PORT"
    return
  fi
  return 127
}

query_sample_outcome() {
  local alias_name="$1" sample="$2" expected_parser="$3" expected_timestamp="$4" min_created="$5"
  local request response output status
  request=$(python3 - "$sample" "$min_created" <<'PY'
import json
import sys

sample, min_created = sys.argv[1:]
filters = [{"term": {"event.original": {"value": sample}}}]
if min_created:
    filters.append({"range": {"event.created": {"gte": min_created}}})
print(json.dumps({"size": 20, "query": {"bool": {"filter": filters}}}))
PY
  ) || return 2

  if ! response=$(curl -fsS --max-time 8 \
    -H 'Content-Type: application/json' \
    -X POST "$ES_URL/$alias_name/_search" \
    --data-binary "$request" 2>&1); then
    printf '%s\n' "$response"
    return 2
  fi

  output=$(python3 - "$PARSER_ID_FIELD" "$expected_parser" "$expected_timestamp" 3<<< "$response" <<'PY'
import json
import os
import sys

field, expected_parser, timestamp_prefix = sys.argv[1:]
with os.fdopen(3) as stream:
    data = json.load(stream)
hits = data.get("hits", {}).get("hits", [])
if not hits:
    raise SystemExit(3)

def nested(source, dotted):
    value = source
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value

reasons = []
for hit in hits:
    source = hit.get("_source", {})
    parser = nested(source, field)
    if parser != expected_parser:
        reasons.append(f"parser={parser!r}")
        continue
    if timestamp_prefix and not str(source.get("@timestamp", "")).startswith(timestamp_prefix):
        reasons.append(f"@timestamp={source.get('@timestamp')!r}")
        continue
    if expected_parser == "pan_simple":
        if nested(source, "source.ip") != "192.168.50.12":
            reasons.append("source.ip mismatch")
            continue
        if nested(source, "destination.port") != 443:
            reasons.append("destination.port is not integer 443")
            continue
        if nested(source, "event.action") != "DROP":
            reasons.append("event.action mismatch")
            continue
    if expected_parser == "pan_full":
        if nested(source, "source.ip") != "192.168.1.100":
            reasons.append("source.ip mismatch")
            continue
        if nested(source, "destination.port") != 443:
            reasons.append("destination.port is not integer 443")
            continue
        if nested(source, "destination.bytes") != 3300:
            reasons.append("destination.bytes is not integer 3300")
            continue
        if nested(source, "destination.packets") != 16:
            reasons.append("destination.packets is not integer 16")
            continue
        if nested(source, "event.action") != "drop":
            reasons.append("event.action mismatch")
            continue
    print(f"index={hit.get('_index')} parser={parser} timestamp={source.get('@timestamp')}")
    raise SystemExit(0)

print("; ".join(reasons) or "matching source document did not meet expectations")
raise SystemExit(4)
PY
  )
  status=$?
  printf '%s\n' "$output"
  return "$status"
}

wait_for_sample() {
  local label="$1" alias_name="$2" sample="$3" expected_parser="$4" expected_timestamp="$5" must_exist="$6" min_created="$7"
  local deadline=$((SECONDS + SAMPLE_WAIT_SECONDS)) output status
  while :; do
    output=$(query_sample_outcome "$alias_name" "$sample" "$expected_parser" "$expected_timestamp" "$min_created")
    status=$?
    if (( status == 0 )); then
      pass "$label reached $alias_name with the expected outcome"
      note "$output"
      return
    fi
    if (( SEND_SAMPLES == 0 || SECONDS >= deadline )); then
      break
    fi
    sleep 2
  done

  if (( status == 3 && must_exist == 0 )); then
    skip "$label is not present; use --send-samples to add and validate it"
  elif (( status == 3 )); then
    fail "$label did not reach $alias_name within ${SAMPLE_WAIT_SECONDS}s"
  else
    fail "$label was found or queried but did not meet the expected outcome"
    show_command_failure "$output"
  fi
}

check_pan_outcomes() {
  section "Mission parser outcomes"
  if ! have_command curl || ! have_command python3; then
    skip "curl and Python 3 are required for PAN outcome checks"
    return
  fi
  local sample_dir="$PROJECT_ROOT/samples/mission"
  local simple_file="$sample_dir/pan-simple.log"
  local full_file="$sample_dir/pan-full.log"
  local unmatched_file="$sample_dir/unmatched.log"
  local date_failure_file="$sample_dir/date-failure.log"
  if [[ ! -s "$simple_file" || ! -s "$full_file" || ! -s "$unmatched_file" || ! -s "$date_failure_file" ]]; then
    fail "One or more canonical mission samples are missing"
    return
  fi
  local simple full unmatched date_failure sample_started=""
  IFS= read -r simple < "$simple_file"
  IFS= read -r full < "$full_file"
  IFS= read -r unmatched < "$unmatched_file"
  IFS= read -r date_failure < "$date_failure_file"

  if (( SEND_SAMPLES == 1 )); then
    sample_started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    if send_tcp_sample "$simple"; then
      pass "Simple PAN sample was sent to $MISSION_TCP_HOST:$MISSION_TCP_PORT"
    else
      fail "Simple PAN sample could not be sent; install nc or timeout/bash and verify the TCP input"
      return
    fi
    if send_tcp_sample "$full"; then
      pass "Full PAN sample was sent to $MISSION_TCP_HOST:$MISSION_TCP_PORT"
    else
      fail "Full PAN sample could not be sent"
      return
    fi
    if send_tcp_sample "$unmatched"; then
      pass "Unmatched mission sample was sent to $MISSION_TCP_HOST:$MISSION_TCP_PORT"
    else
      fail "Unmatched mission sample could not be sent"
      return
    fi
    if send_tcp_sample "$date_failure"; then
      pass "Invalid-date PAN sample was sent to $MISSION_TCP_HOST:$MISSION_TCP_PORT"
    else
      fail "Invalid-date PAN sample could not be sent"
      return
    fi
  else
    note "No events will be sent; searching only for previously indexed fixtures."
  fi

  wait_for_sample "Simple PAN sample" "$PAN_MATCH_ALIAS" "$simple" \
    "$PAN_SIMPLE_EXPECTED_PARSER" "$PAN_SIMPLE_EXPECTED_TIMESTAMP_PREFIX" "$SEND_SAMPLES" "$sample_started"
  wait_for_sample "Full PAN sample" "$PAN_MATCH_ALIAS" "$full" \
    "$PAN_FULL_EXPECTED_PARSER" "$PAN_FULL_EXPECTED_TIMESTAMP_PREFIX" "$SEND_SAMPLES" "$sample_started"
  wait_for_sample "Unmatched mission sample" "$PAN_UNMATCHED_ALIAS" "$unmatched" \
    "$PAN_UNMATCHED_EXPECTED_PARSER" "" "$SEND_SAMPLES" "$sample_started"
  wait_for_sample "Invalid-date PAN sample" "$PAN_UNMATCHED_ALIAS" "$date_failure" \
    "$PAN_DATE_FAILURE_EXPECTED_PARSER" "" "$SEND_SAMPLES" "$sample_started"
}

run_runtime_checks() {
  check_host_aliases
  check_deployed_compose
  check_containers
  check_gitlab_bindings
  check_service_endpoints
  check_loopback_bindings
  check_sensor_logs
  check_kafka_topics
  check_elastic_contract
  check_kibana_data_views
  check_sensor_outcomes
  run_native_config_tests
  check_pan_outcomes
}
