# First deployment and evidence checklist

This sequence assumes GitLab, Docker, Ansible, SSH, Zeek, and Suricata are
already installed. The training branch contains the supported new-host GitLab
bootstrap; this document starts at the answer implementation boundary.

If you are continuing from the manual checkpoint, stop all seven manual
Compose projects in the documented reverse order before deploying this state.
The managed projects under `/var/docker` reuse their container names and host
ports. Leave the separate GitLab project and `/var/training/gitlab` untouched.

## 1. Prove host prerequisites

Confirm the inventory hostname and application aliases resolve to loopback,
the host SSH service is reachable, sensor logs exist, and required ports are
not occupied by unrelated processes.

```bash
getent hosts mini-manticore.local elasticsearch.local kafka.local kibana.local
ssh ansible@mini-manticore.local id
sudo test -d /opt/zeek/logs/current
sudo test -s /var/log/suricata/eve.json
sudo ss -ltnp
```

Zeek records must be newline-delimited JSON. Inspect one complete line instead
of assuming a `.log` suffix implies the required format. Confirm
`vm.max_map_count` can be changed by the Ansible account's intended privilege
policy; the host role sets it to `1048576`.

## 2. Prepare Ansible inputs

Install the pinned collections and create the ignored local Vault working
file:

```bash
ansible-galaxy collection install -r requirements.yml -p .ansible/collections
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
chmod 0600 group_vars/all/vault.yml
${EDITOR:-vi} group_vars/all/vault.yml
```

Populate only the privilege-escalation credential required by this host. Do
not store SSH private keys in inventory or variables. Each initiating account
uses its own default-protected key and verified `known_hosts` entry.

```bash
ansible-inventory --graph
ansible-inventory --host mini-manticore.local
ansible mini_manticore_hosts -m ping
ansible mini_manticore_hosts -b -m command -a 'id -u'
```

The resolved inventory must show one host in `mini_manticore_hosts` and all six
service groups, `ansible_connection=ssh`, and `ansible_user=ansible`. It must
not replace the inventory hostname with `127.0.0.1` through `ansible_host`.

## 3. Run static checks before mutation

```bash
bash validation/validate.sh static
```

Resolve failures. A `SKIP` for an unavailable Docker or Ansible executable
means that check was not performed; it is not passing evidence.

## 4. Deploy in the reference order

For the complete deployment:

```bash
ansible-playbook roles-all.yml
```

For learning or diagnosis, run the same component boundaries explicitly:

```bash
ansible-playbook roles-system_files_setup.yml
ansible-playbook roles-elasticsearch_nodes.yml
ansible-playbook roles-queue_nodes.yml
ansible-playbook roles-logstash_nodes.yml
ansible-playbook roles-logstash_port-router.yml
ansible-playbook roles-web_servers.yml
ansible-playbook roles-network_sensors.yml
```

Do not run a manual playbook while a GitLab deployment job holds the lab
resource lock.

## 5. Prove runtime behavior

Run read-only checks plus native parser/configuration checks:

```bash
bash validation/validate.sh all --config-tests
```

Then deliberately add the mission fixtures and verify their destinations:

```bash
bash validation/validate.sh runtime --send-samples
```

Also generate fresh network traffic and record one new Zeek and one new
Suricata document. A fixture already present from an earlier run is not proof
that the current collector path works.

Manual observations should include:

- GitLab remains healthy and its Compose project is unchanged;
- all unauthenticated listeners are loopback-only;
- `kafka-topics-init` created any missing topics successfully;
- all three processing pipelines and the port-router pipeline are available;
- each backing index has its intended template and one write alias;
- all four Kibana data views use `@timestamp`; and
- valid, unmatched, and invalid-date mission records meet
  `samples/mission/expected-outcomes.yml`.

## 6. Prove idempotence and drift correction

Run the same full playbook a second time and retain its recap:

```bash
mkdir -p validation/evidence
set -o pipefail
ansible-playbook roles-all.yml \
  | tee validation/evidence/ansible-idempotence.txt
bash validation/validate.sh static \
  --idempotence-log validation/evidence/ansible-idempotence.txt
```

Every second-run host recap must report `changed=0`, `unreachable=0`, and
`failed=0`. Then alter one harmless managed file in `/var/docker`, run the
owning playbook, and show that Ansible repairs it and activates the repaired
configuration without touching GitLab.

## 7. Complete the security transition

Only after the plaintext variable flow works, encrypt and deliberately track
the Vault file:

```bash
ansible-vault encrypt group_vars/all/vault.yml
git add -f group_vars/all/vault.yml
```

Test one correct and one incorrect Vault password. Configure the protected
GitLab variable and runner SSH boundary described in the
[identity and Vault guide](identity-and-vault.md) before enabling mutating CI
jobs.
