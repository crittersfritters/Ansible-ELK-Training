# Mini-Manticore Training

Mini-Manticore Training is a self-paced construction lab. You will build a
localhost data path with Docker Compose, Zeek, Suricata, Filebeat, Kafka,
Logstash, Elasticsearch, Kibana, Ansible, and GitLab CI.

This branch describes outcomes, not recipes. It intentionally omits working
service definitions, parser patterns, Ansible roles, and deployment jobs. You
are expected to research unfamiliar concepts, test your assumptions, and ask
questions when you cannot identify the next useful question.

The `answer-sheet` branch is a reference implementation, not the only valid
implementation. Consult it when you are blocked; do not assume every design
choice there is mandatory unless this branch labels it as a course contract.

## Learning objectives

By completing the course, you should be able to:

- explain what each Elastic Stack component contributes to the data path;
- follow an event across Filebeat, Kafka, Logstash, Elasticsearch, and Kibana;
- configure and troubleshoot Filebeat inputs, state, and outputs;
- distinguish an index, index template, alias, and Kibana data view;
- develop, order, and test Grok parsers against known input;
- build and troubleshoot separate Docker Compose projects;
- convert a working manual deployment into idempotent Ansible automation; and
- use a learner-authored GitLab pipeline to apply a repository change.

GitLab is included so that you experience the change path used by the larger
environment. Designing advanced GitLab CI is not a course objective.

## Lab boundaries

- Run the entire lab on one Linux host.
- Use a normal learner account, the `gitlab-runner` account created during
  bootstrap, and a separate `ansible` account introduced at Milestone 07.
- Have Ansible reach the host through SSH as the `ansible` account, even though
  the target resolves to localhost.
- Treat GitLab as a separate bootstrap Compose project. Mini-Manticore
  automation must not manage or remove it.
- Build seven Mini-Manticore Compose projects: Elasticsearch, Kibana, Kafka,
  processing Logstash, port-router Logstash, Zeek Filebeat, and Suricata
  Filebeat.
- Install Zeek and Suricata on the host; the Filebeat projects collect their
  output.
- Keep the lab isolated. Its simplified networking and security choices are
  training constraints, not production guidance.
- Bind every unauthenticated application listener to loopback. Do not expose
  Elasticsearch, Kibana, Kafka, Logstash, or GitLab to another network.
- Treat membership in the Docker group as root-equivalent access.
- Preserve the course's required service interfaces and observable data
  behavior. Repository layout and implementation details are yours to design.

## How to work

Complete the milestones in order. For each milestone:

1. Read its goal and behavioral requirements.
2. Record the questions you need to answer.
3. Build the smallest version that satisfies the requirements.
4. Prove every completion criterion by direct observation.
5. Commit the working state before proceeding.
6. Record what failed, what evidence identified the cause, and what changed.

There is no supplied grader on this branch. A container listed as running is
not sufficient proof that a data path works. Completion means you can produce
and explain the requested evidence.

## Starting from a new Linux installation

The supported course baseline is a fresh Ubuntu 24.04 LTS host with at least 4
CPU cores, 16 GiB RAM, and 80 GiB free disk. More memory is useful when GitLab
and the full stack run together. Other Linux distributions are valid learning
choices, but you must translate the bootstrap and keep the same outcomes.

Obtain this repository from the maintainer's Git account by cloning it or by
copying an archive. Then:

1. Install Git, Docker Engine, the Docker Compose plugin, Python, Ansible, an
   SSH client and server, and ordinary troubleshooting tools.
2. Ensure your normal account can operate Docker using your host's intended
   administrative model.
3. Configure a local hostname for GitLab and confirm it resolves to the local
   host.
4. Complete the GitLab bootstrap milestone.
5. Create a blank **Mini-Manticore Training** project in your local GitLab.
6. Add the local project as a Git remote and push the `training` branch. If the
   reference branch was supplied to you, push `answer-sheet` separately and
   leave `training` as the default branch.
7. Clone the project back from local GitLab into the location where you will
   do the course work. This verifies that the local instance, repository, and
   Git transport are usable before the stack is involved.

Do not copy implementation files from the answer branch into the training
branch. When you consult a reference, return to your own design and explain
why your chosen implementation satisfies the requirement.

## Course files at this checkpoint

- [Course map](docs/course-map.md) — milestone sequence and expected evidence
- [Working contract](docs/working-contract.md) — decisions that must remain
  consistent across components
- [Milestones](docs/milestones/) — GitLab bootstrap, manual stack, Ansible,
  Vault, and learner-authored CI stages
- [GitLab bootstrap](docs/gitlab-bootstrap.md) — the explicit path from a new
  host through a repository cloned from the local GitLab instance

The final curriculum commit adds the sanitized inputs and expected outcomes.
Begin with
[Host and GitLab bootstrap](docs/milestones/00-host-and-gitlab.md); later work
intentionally remains outcome-based.
