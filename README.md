# Mini-Manticore Training — answer sheet

This branch is the complete reference implementation for the localhost course.
It is one valid design, not the only valid design. The default `training`
branch states outcomes and leaves the implementation to the learner.

The reference preserves the original learning path: build the stack manually,
prove it, convert it to Ansible over SSH using a dedicated `ansible` account,
encrypt deployment credentials with Ansible Vault, and finally deploy through
a host-installed GitLab shell runner. Earlier manual states remain available at
the annotated answer checkpoint tags.

## What this branch contains

- a separate GitLab bootstrap Compose project under `bootstrap/gitlab`;
- one localhost inventory host in six logical Ansible service groups;
- seven independently managed Mini-Manticore Compose projects;
- native Zeek and Suricata sources collected by two Filebeat projects;
- Kafka topic initialization, processing Logstash, and mission port routing;
- four composable index templates, backing indices, write aliases, and Kibana
  data views;
- ordered Grok parsers with explicit successful and failed outcomes;
- a protected-ref, dependency-aware GitLab child pipeline; and
- static plus non-destructive runtime validation under `validation`.

Docker is a prerequisite. The playbooks intentionally do not install,
reconfigure, restart, or prune Docker because the same daemon owns GitLab.

## Reference baseline

The release candidate targets Ubuntu 24.04 LTS, GitLab CE `19.3.2-ce.0`,
Elastic Stack `9.2.8`, Apache Kafka `3.9.2`, and Kafka UI `v0.7.2`. Budget at
least 4 CPU cores, 16 GiB RAM, and 80 GiB free disk for GitLab and the complete
stack. All unauthenticated application listeners are restricted to loopback.

## Before the first playbook

1. Complete the [GitLab bootstrap](bootstrap/gitlab/README.md) or compare it
   with the matching training milestone.
2. Install and configure Zeek to emit JSON under `/opt/zeek/logs/current` and
   Suricata to emit `/var/log/suricata/eve.json`. The supported-host reference
   is in [native sensor setup](docs/sensor-host-setup.md).
3. Create the `ansible` account, its privilege policy, and SSH keys. Make
   `mini-manticore.local` resolve to `127.0.0.1`, then verify SSH host keys and
   key authentication instead of disabling host-key checking.
4. Install Ansible collections into the checkout:

   ```bash
   python3 -c 'import yaml, requests'
   ansible-galaxy collection install -r requirements.yml \
     -p .ansible/collections
   ```

5. Create the ignored initial credential file and replace its placeholder:

   ```bash
   cp group_vars/all/vault.yml.example group_vars/all/vault.yml
   chmod 0600 group_vars/all/vault.yml
   ${EDITOR:-vi} group_vars/all/vault.yml
   ```

6. Verify the boundary, then deploy:

   ```bash
   ansible-inventory --graph
   ansible mini_manticore_hosts -m ping
   ansible-playbook roles-all.yml
   ```

The full playbook prepares the host once, then deploys Elasticsearch, Kafka,
processing Logstash, the mission port router, Kibana, and the two Filebeat
collectors in dependency order. It does not own the GitLab project.

## Vault and CI transition

After a plaintext local run works, encrypt the entire ignored variable file:

```bash
ansible-vault encrypt group_vars/all/vault.yml
git add -f group_vars/all/vault.yml
```

Set `ANSIBLE_VAULT_PASSWORD` as a masked, protected GitLab CI/CD variable. The
checked-in `vault_password.sh` returns that environment value to Ansible. The
answer pipeline refuses a missing or plaintext Vault file and deploys only from
a protected ref on the `mini-manticore-local` runner.

## Validation

Run repository-only checks anywhere Python 3 and PyYAML are available:

```bash
bash validation/validate.sh static
```

On the prepared Linux host, run read-only live checks or explicitly add test
mission events:

```bash
bash validation/validate.sh all --config-tests
bash validation/validate.sh runtime --send-samples
```

This candidate was statically validated in its build environment. Docker,
Ansible, GitLab CI, sensor, idempotence, and full data-path checks require the
target Linux host and remain release gates before replacing the RC tags with a
final course release.

## Documentation

- [Reference contract](docs/reference-contract.md) — authoritative names,
  ports, paths, and data outcomes
- [Architecture](docs/architecture.md) — localhost topology and ownership
  boundaries
- [First deployment](docs/first-deployment.md) — ordered deployment and
  evidence checklist
- [Identity and Vault](docs/identity-and-vault.md) — learner, Ansible, runner,
  SSH, and Vault model
- [Mission parsing](docs/mission-parsing.md) — parser and failure-routing
  explanation
- [Native sensor setup](docs/sensor-host-setup.md) — Zeek and Suricata
  installation reference
- [GitLab CI](docs/gitlab-ci.md) — advanced dependency-aware reference
  pipeline
- [Lab reset](docs/lab-reset.md) — bounded resets that leave GitLab alone
- [Troubleshooting](docs/troubleshooting.md) — symptom-to-boundary diagnostics
- [Checkpoints](docs/checkpoints.md) — course milestone and tag map
- [Maintainer release guide](docs/maintainer/release.md) — branch, audit,
  validation, and export process
