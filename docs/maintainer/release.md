# Mini-Manticore Training maintainer release guide

The artifacts built in this workspace use release-candidate tags because the
build host lacks Docker and Ansible. Do not promote them to final `v1.0` tags
until every target-host gate below has been recorded.

## Repository roles

Maintain these as independent repositories:

| Repository | Purpose |
|---|---|
| **Mini-Manticore** | Current maintained implementation used as an upstream source of selected fixes and design changes |
| **Mini-Manticore Training** | Versioned course with a deliberately sparse learner branch and a tested reference branch |

Do not mirror or automatically merge **Mini-Manticore** into the course. A
working-site change is not automatically appropriate for a localhost teaching
environment, and a wholesale merge can expose solutions in the learner branch.

## Canonical branches

**Mini-Manticore Training** has two canonical branches:

| Branch | Role |
|---|---|
| `training` | Default branch containing curriculum, samples, contracts, and observable completion criteria without working stack code |
| `answer-sheet` | Complete reference implementation with staged history and automated validation |

Protect both branches. Require merge requests or maintainer-level direct-push
permission, prevent force pushes, and prevent deletion. Learners work from a
personal branch or fork based on `training`.

The answer sheet is a reference implementation, not an access boundary. Anyone
who can read the repository can inspect or compare it. Use a separate private
repository only if a future course must delay solution access.

## Safe initial history

Never create `training` by committing the answer and then deleting its files.
The deleted solution remains available in branch history.

Use one neutral seed commit containing only repository-level material that is
safe on both branches, then create both canonical branches from that commit.
Develop the answer only on `answer-sheet`. Develop the curriculum only on
`training`.

Before first publication, verify the entire reachable history of `training`,
not merely its tip. If answer code ever entered that history, rewrite it before
others clone the repository; after publication, prefer a new clean branch or
repository and treat the exposed solution as already disclosed.

## Answer-sheet checkpoints

Build the answer in meaningful, functional commits rather than importing one
finished tree. Preserve at least these checkpoints:

1. GitLab bootstrap and localhost contract;
2. manual Elasticsearch and Kibana;
3. Zeek and Suricata installation and log production;
4. direct Filebeat-to-Logstash-to-Elasticsearch paths;
5. Kafka insertion and topic initialization;
6. mission port router and Grok parsing;
7. first Ansible role;
8. reusable Ansible deployment behavior;
9. all seven Compose projects managed by Ansible;
10. Vault encryption; and
11. GitLab CI deployment.

The final answer tree may contain only the Ansible-managed form. Earlier manual
files remain inspectable through their tagged checkpoint instead of being
duplicated beside the final implementation.

For course version `1.0`, use annotated tags with a consistent namespace:

| Tag | Target |
|---|---|
| `course-v1.0-rc1-answer-manual` | Statically verified fully manual stack commit on `answer-sheet` |
| `course-v1.0-rc1-answer-ansible` | Statically verified full Ansible reconstruction commit |
| `course-v1.0-rc1-answer` | Final RC `answer-sheet` commit |
| `course-v1.0-rc1-training` | Matching `training` curriculum RC commit |

Tags are repository-wide names; do not reuse or move a published release tag.
Increment the course version when either branch changes in a way that alters
the paired learner/reference experience.

## Curriculum-to-answer traceability

Maintain a private or answer-sheet-side release matrix with one row per
training milestone:

| Field | Meaning |
|---|---|
| Milestone identifier | Stable curriculum label |
| Training document | Goal and completion-criteria location |
| Required sample | Input used to prove behavior |
| Interface contract | Names, ports, topics, fields, or destinations that must agree |
| Answer commit or checkpoint | Earliest reference state that satisfies the milestone |
| Automated answer test | Validation proving the reference remains correct |

This mapping is for course maintenance. Do not copy implementation paths or
answer commit hashes into learner instructions when they would reveal the
solution more directly than intended.

## Porting changes from Mini-Manticore

Port upstream work in a controlled integration branch created from the current
`answer-sheet` tip.

1. Fetch the selected, tested Mini-Manticore revision into a separate remote.
2. Read the change and identify the behavior or defect it addresses.
3. Classify it as applicable, adaptable, curriculum-only, or out of scope.
4. Reimplement or selectively cherry-pick it into the localhost answer branch.
5. Resolve topology assumptions explicitly: one inventory host, one Docker
   daemon, one host port space, and GitLab outside Mini-Manticore ownership.
6. Run answer validation before deciding whether the curriculum must change.
7. If learner-visible requirements change, update `training` independently and
   review it for answer leakage.
8. Merge each branch through its own reviewed merge request.

Do not merge the Mini-Manticore repository wholesale. In particular, review
every change for these common multi-node assumptions:

- distinct IP addresses or host variables;
- the same port being available on multiple physical machines;
- system setup executed once per inventory host;
- a firewall local to only one service;
- Compose projects on separate Docker daemons;
- host-networked containers that can reuse a port only because they are on
  different VMs; and
- CI jobs described as node jobs rather than component reconciliation.

Record the selected Mini-Manticore commit in the course release notes. The
record provides provenance; it does not establish an ongoing synchronization
relationship.

## Validation gates

Create final release tags only when every applicable gate passes. An RC may be
distributed for target-host validation when static gates pass and every
deferred runtime gate is listed in its manifest.

### Static answer validation

- All YAML and structured configuration parses.
- All seven Compose projects render without unresolved variables.
- The GitLab Compose project renders independently.
- Ansible inventory contains one host in every intended group.
- Ansible playbooks pass syntax checks.
- Required roles and collections resolve at pinned versions.
- Logstash and Filebeat configurations pass their native configuration tests.
- CI configuration passes GitLab validation for the pinned GitLab version.

### Runtime answer validation

- GitLab and its runner remain operational while Mini-Manticore is deployed,
  updated, and reset.
- Elasticsearch, Kafka, processing Logstash, the port router, Kibana, and both
  Filebeat projects reach their intended state.
- The one-shot Kafka topic initializer exits successfully and required topics
  exist.
- Zeek and Suricata create fresh readable events.
- Zeek, Suricata, and mission events traverse their complete paths.
- Valid mission samples receive required fields, parser identity, source-event
  time, and destination routing.
- Unmatched, timed-out, and malformed samples follow their specified failure
  behavior.
- Persistent state survives the documented ordinary container recreation.

### Ansible answer validation

- A clean Mini-Manticore deployment directory can be reconstructed.
- Host preparation executes once against the one physical host.
- A second unchanged run is idempotent.
- Deliberate drift is corrected.
- A changed bind-mounted configuration becomes active without an undocumented
  manual restart.
- The deployment never removes, recreates, or changes the GitLab Compose
  project.
- Both correct and incorrect Vault passwords produce the expected result.

### GitLab answer validation

- A non-mutating preflight uses the expected shell runner.
- The runner reaches `ansible@mini-manticore.local` through SSH.
- Dependency installation is reproducible from the pinned manifest.
- The changed-path acceptance cases in the answer CI document select the
  expected jobs and order.
- Selected failures stop later stages and remain visible.
- Resource groups prevent overlapping mutations of the one host.
- A successful CI change is observable in the running service.

### Training-branch validation

- Instructions contain goals, contracts, completion criteria, and research
  prompts rather than completed implementation.
- All seven Compose projects remain learner-created.
- No working Ansible playbook, role, Filebeat configuration, Logstash pipeline,
  Grok pattern, Kafka configuration, or deployment pipeline is present.
- Supplied expected outcomes reveal document behavior, not implementation
  syntax.
- GitLab bootstrap guidance does not include completed Compose YAML.
- Every milestone is achievable by the matching answer release.
- Links, filenames, samples, and terminology are internally consistent.

### Leakage and history audit

Search the training tree and every commit reachable from `training` for:

- answer-only filenames;
- complete Compose service definitions;
- Ansible module invocations and finished task sequences;
- complete Grok expressions;
- Filebeat and Logstash output blocks;
- Kafka listener configuration;
- the dependency-aware CI map;
- credentials, tokens, private keys, and Vault passwords; and
- archived or generated files that contain any of the above.

Review search results manually. Absence of one keyword is not proof that a
solution did not leak.

## Release procedure

1. Freeze the intended tips of `training` and `answer-sheet` in release merge
   requests.
2. Record both commit IDs and the selected Mini-Manticore source revision.
3. Complete all validation gates and retain the results with the release.
4. Create the manual and Ansible checkpoint tags at their verified answer
   commits.
5. Create the paired final tags at the two frozen branch tips.
6. Push branches and annotated tags.
7. Confirm `training` remains the default branch and both canonical branches
   retain protection.
8. Produce and verify the release exports below.
9. Generate checksums and a manifest containing filenames, sizes, commit IDs,
   tag targets, validation date, and tool versions that affect reproducibility.
10. Clone or extract each artifact into a temporary location and verify it
    independently before distribution.

Do not create tags before validation and then move them after a fix. Correct
the branch and create a new course version if a published tag was wrong.

## Git bundle export

A Git bundle preserves commit history, both canonical branches, and tags. From
a clean repository with all intended refs fetched, create the complete course
bundle:

```bash
git switch training
git status --short
git bundle create Mini-Manticore-Training-course-v1.0-rc1.bundle \
  HEAD refs/heads/training refs/heads/answer-sheet \
  refs/tags/course-v1.0-rc1-training \
  refs/tags/course-v1.0-rc1-answer \
  refs/tags/course-v1.0-rc1-answer-manual \
  refs/tags/course-v1.0-rc1-answer-ansible
git bundle verify Mini-Manticore-Training-course-v1.0-rc1.bundle
```

Verify the advertised refs include `training`, `answer-sheet`, and all release
tags. Advertising `HEAD` while `training` is checked out makes a normal bundle
clone select the learner branch. Clone the bundle into a temporary directory
and inspect its checked-out branch, log, and refs.

The bundle contains the answer sheet. It is suitable for the agreed course,
where learners may consult the answer branch. Do not use the same bundle if a
future delivery must conceal answers.

To restore into an empty remote, clone the bundle, add the destination remote,
push the two canonical branches, and push the release tags. Branch protection,
default-branch selection, runners, variables, and other GitLab project settings
are not stored in a Git bundle and must be recreated at the destination.

## Branch ZIP exports

ZIP exports are convenience snapshots. They do not contain Git history and
cannot preserve the staged answer checkpoints.

Create them from the immutable release tags rather than the mutable branch
names:

```bash
git archive \
  --format=zip \
  --output=Mini-Manticore-Training-course-v1.0-rc1-training.zip \
  course-v1.0-rc1-training

git archive \
  --format=zip \
  --output=Mini-Manticore-Training-course-v1.0-rc1-answer.zip \
  course-v1.0-rc1-answer
```

Inspect both archive listings. Extract each into a new temporary directory and
run the branch-appropriate static checks. Confirm the training ZIP contains no
answer-only material.

Generate a checksum file after the bundle and both ZIPs are final:

```bash
sha256sum \
  Mini-Manticore-Training-course-v1.0-rc1.bundle \
  Mini-Manticore-Training-course-v1.0-rc1-training.zip \
  Mini-Manticore-Training-course-v1.0-rc1-answer.zip \
  > Mini-Manticore-Training-course-v1.0-rc1.sha256
```

Checksums prove that a downloaded artifact matches the released bytes; they do
not replace signature verification or repository access controls.

## Release manifest

Publish a small text or Markdown manifest beside the artifacts with:

- course version and release date;
- `training` and `answer-sheet` commit IDs;
- checkpoint tag names and commit IDs;
- selected Mini-Manticore source revision;
- artifact filenames, byte sizes, and SHA-256 checksums;
- pinned GitLab, Elastic Stack, Kafka, Ansible, role, and collection versions;
- host platform used for runtime validation;
- validation gates completed and any explicitly deferred tests; and
- known disposable-lab limitations.

Never claim runtime validation for a check performed only by parsing or static
inspection.

## Updating a published course

For corrections that do not change learner outcomes, update both branches as
needed, rerun the applicable gates, and publish a patch course release.

For new milestones, service contracts, sample formats, version changes, or
different expected output, publish a new minor or major course release. Keep
old tags immutable so an active learner can finish against the version they
started.

At each update, ask two separate questions:

1. Does the answer implementation still work on the tested host?
2. Does the training branch still require the learner to discover the answer?

A release is incomplete if only one of those is true.
