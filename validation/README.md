# Mini-Manticore answer-sheet validation

This directory validates the reference implementation without stopping,
recreating, or deleting any service or data. The default run performs static
checks only and works on a development machine that does not have Docker or
Ansible installed. Checks that need an unavailable program are reported as
`SKIP`, not as false failures.

Run the static suite from anywhere in the repository:

```bash
bash ./validation/validate.sh static
```

On the Linux training host, run static and live, read-only checks together:

```bash
bash ./validation/validate.sh all
```

If Docker requires privilege escalation, supply the command explicitly:

```bash
DOCKER_COMMAND="sudo docker" bash ./validation/validate.sh all
```

The exit status is nonzero only when a check reports `FAIL`. Warnings and
skipped checks remain visible in the summary but do not fail the run.

## What the suites cover

The static suite checks:

- required answer-sheet files, all seven Compose templates, and both rendered
  Filebeat configurations;
- YAML syntax when Python and PyYAML are available;
- concrete Compose files with `docker compose config` when any exist;
- the GitLab bootstrap's exact pinned image, identity, Omnibus settings,
  loopback publications, and persistent mounts;
- Ansible inventory structure and playbook syntax when Ansible is available;
- the localhost inventory model: one host in all six service groups;
- the presence of Logstash, Filebeat, all four mission samples, and CI
  configuration;
- local Markdown link integrity; and
- optional idempotence evidence from a prior second playbook run.

The runtime suite checks, without changing the running stack:

- `/etc/hosts` and resolver results for the required localhost aliases;
- rendered Compose files under `/var/docker`;
- required healthy/running containers and the successful one-shot topic
  initializer;
- Docker SELinux integration and effective container process types whenever
  host SELinux is enabled;
- Elasticsearch, available Kibana, Kafka UI, the GitLab sign-in page, and both
  Logstash API endpoints;
- GitLab's Docker-reported health, pinned image, Compose ownership, persistent
  mounts, Omnibus settings, and exact HTTP, port 443, and SSH loopback
  publications;
- loopback-only listeners for the host-networked Mini-Manticore ports;
- canonical Zeek source resolution, conditional external-target coverage,
  and read-only non-relabeling sensor mounts;
- the Suricata log-reader domain and preserved native EVE label on SELinux
  hosts;
- byte-level access to real nonempty Zeek and Suricata source files from the
  running collectors;
- required Kafka topics;
- Elasticsearch backing-index mappings, write aliases, and applicable
  composable index templates;
- all four Kibana data views;
- recent Zeek and Suricata records proving both complete sensor paths; and
- the four canonical mission records and their expected parser destinations,
  when present.

All names and endpoints are centralized in `contract.env`. Environment
variables override its defaults, so local differences do not require editing
the check scripts.

## Logstash and Filebeat configuration tests

The ordinary runtime suite only observes the active processes. To ask the
installed Logstash and Filebeat binaries to parse their mounted configuration,
add `--config-tests`:

```bash
bash ./validation/validate.sh runtime --config-tests
```

Logstash receives a unique temporary `path.data` inside its existing container
so the validation process does not contend with the running instance. Each
Filebeat receives its own temporary `path.data` and runs both `test config`
and `test output`, proving configuration parsing and Kafka connectivity without
contending with the active registry. The Filebeat temporary directories are
removed after each check. These commands do not stop or restart containers.

If the containers are not running, use the image's native commands manually
after rendering the configuration:

```text
logstash --path.settings <settings-directory> --path.data <unique-temp-path> --config.test_and_exit
filebeat test config -c <filebeat.yml>
```

Do not point the Logstash test at the running process's normal `path.data`.

## PAN outcome checks

By default, runtime validation searches for the four exact records under
`samples/mission/`. If they have not previously been sent, those checks are
skipped.

To send all four records to the existing TCP input and then validate their indexed
outcomes, opt in explicitly:

```bash
bash ./validation/validate.sh runtime --send-samples
```

This operation **adds four training events**. It never removes documents,
indices, aliases, topics, offsets, or containers. The matching record must
appear through `active-grok-match` with the expected visible parser identity,
field types, and source timestamp. The unmatched and invalid-date records must
appear through `active-unparsed`. When events are sent, `event.created` must be
at or after this validation invocation, so an old identical document cannot
hide a broken current path.

Override the host, port, wait time, or parser field when necessary:

```bash
MISSION_TCP_HOST=127.0.0.1 \
MISSION_TCP_PORT=4444 \
SAMPLE_WAIT_SECONDS=45 \
PARSER_ID_FIELD=_parser.id \
bash ./validation/validate.sh runtime --send-samples
```

The sensor outcome check requires a conforming Zeek and Suricata document no
older than `SENSOR_MAX_AGE` (default `24h`). Generate fresh traffic observed by
both native sensors before release validation; a stale fixture is not proof
that the current Filebeat-to-Kafka-to-Logstash path works.

## Idempotence evidence

The harness intentionally does not run a deployment playbook: proving
idempotence requires a real second normal run, which may reconcile managed
state. After a successful deployment, run the same playbook again yourself and
capture the complete second-run output:

```bash
ansible-playbook -i site-config.yml roles-all.yml \
  | tee validation/evidence/ansible-idempotence.txt
```

Then validate the recap without rerunning Ansible:

```bash
bash ./validation/validate.sh static \
  --idempotence-log validation/evidence/ansible-idempotence.txt
```

Every host recap must report `changed=0`, `unreachable=0`, and `failed=0`.
The evidence file is ignored by Git so host-specific output and incidental
details are not committed.

## Safety boundary

The harness contains no `DELETE` requests, `docker compose down`, container
stop/restart/remove operations, Kafka topic mutations, or Ansible deployment
calls. Static validation removes only its own newly created temporary render
directory. HTTP `POST` is used only for Elasticsearch search bodies;
Elasticsearch searches do not mutate cluster state.
