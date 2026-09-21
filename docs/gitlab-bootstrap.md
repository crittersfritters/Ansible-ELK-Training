# Build the local GitLab environment

## Why this milestone is more explicit

GitLab is the entry point for the rest of the course. You cannot use a local
GitLab project until the service exists, so this milestone provides a firmer
contract than later Mini-Manticore exercises.

You will still write the Compose file yourself. This document identifies the
required pieces and the result to prove; it does not provide completed YAML.

GitLab is bootstrap infrastructure. Keep its Compose project, configuration,
and persistent state separate from the seven Mini-Manticore Compose projects.
Later Ansible work must not manage or remove this project.

## Starting point and required capabilities

Obtain the `training` branch from the maintainer's Git account by cloning it or
copying the branch archive. At this point, the authoritative copy is upstream;
your local GitLab does not exist yet.

Use a maintained Linux host that can provide the following capabilities:

- Git;
- Docker Engine with the Docker Compose v2 plugin;
- an SSH client and host SSH service;
- Python 3 with YAML and HTTP client libraries;
- Ansible Core and `ansible-galaxy`; and
- ordinary network, process, storage, and text-inspection tools.

Install them using current documentation for the selected host and each
upstream project. The course intentionally does not translate package names,
repositories, service units, or upgrade commands for a particular
distribution. Those are host-administration decisions, not Mini-Manticore
contracts.

Verify the resulting capabilities rather than assuming that installation
completed correctly:

```bash
git --version
docker version
docker compose version
docker run --rm hello-world
ssh -V
python3 --version
ansible-playbook --version
ansible-galaxy --version
python3 -c 'import yaml, requests; print(yaml.__version__, requests.__version__)'
```

Use the host's intended administrative model if Docker requires privilege
escalation. Membership in Docker's control group is root-equivalent; grant it
deliberately rather than treating it as an ordinary convenience group.

A host-wide Ansible installation is intentional. The later shell runner must
execute the same tools without inheriting the learner's interactive shell
configuration.

Install Zeek and Suricata later in Milestone 02, not as hidden containers
during this bootstrap.

Before proceeding, the host must have these capabilities:

- Docker Engine and the Docker Compose plugin;
- Git;
- an SSH client and server;
- a hostname entry that resolves `gitlab.local` to the local host; and
- enough available CPU, memory, and disk for GitLab plus the later training
  stack.

Do not continue until an ordinary test container and a small test Compose
project both run successfully.

## Reserve non-conflicting endpoints

The complete course runs GitLab and Mini-Manticore on the same machine. Before
writing the GitLab project, inventory the ports already listening on the host
and verify that the fixed course ports `8929` for HTTP and `2224` for Git SSH
are free. Do not bind the container's SSH service to host port `22`; that port
belongs to the host SSH server used by Ansible. Publish both course ports only
on `127.0.0.1`; the unauthenticated training instance must not be reachable
from another host.

Add `127.0.0.1 gitlab.local` to `/etc/hosts` with an administrative editor and
prove that `getent hosts gitlab.local` returns loopback before starting GitLab.

Because the web listener is loopback-only, open it in a browser on the training
host. For a headless host, use an authenticated SSH local-forward from the
administrative workstation, for example `-L 8929:127.0.0.1:8929`. Map
`gitlab.local` to `127.0.0.1` on that workstation and browse
`http://gitlab.local:8929` so GitLab's canonical external URL still agrees
with the browser request. Do not solve access by changing the publication to
`0.0.0.0`.

## Create the Compose project

Create a dedicated host directory for the GitLab project. Its contents must
not be nested inside a Mini-Manticore service directory.

Write a Compose file with one GitLab service. It must satisfy every item in
this table.

| Area | Requirement |
|---|---|
| Edition | Use the official GitLab Community Edition image, `gitlab/gitlab-ce`. |
| Version | Pin a complete image tag. Do not use `latest`. The release-candidate baseline is `19.3.2-ce.0`; later releases must select a current security-patched version deliberately. |
| Service identity | Give the service and container stable, recognizable names. |
| Hostname | Configure GitLab to identify itself as `gitlab.local`. |
| Network mode | Use ordinary Compose port publishing rather than host networking. GitLab's internal SSH listener must remain distinct from the host SSH listener. |
| External web URL | Set GitLab's `external_url` to the hostname and host web port you reserved. |
| Advertised SSH port | Set `gitlab_rails['gitlab_shell_ssh_port']` to the host-side Git SSH port you reserved. |
| Published ports | Bind host ports `8929` and `2224` to `127.0.0.1`; publish them to GitLab's configured web listener and container port `22`, respectively. |
| Persistence | Bind-mount or volume-mount GitLab's `/etc/gitlab`, `/var/log/gitlab`, and `/var/opt/gitlab` directories to three separate persistent locations. |
| Restart behavior | Configure GitLab to return after an ordinary host or Docker restart. |
| Shared memory | Allocate at least 256 MiB of shared memory to the GitLab service. |
| Secrets | Do not commit a root password, runner authentication token, personal access token, or SSH private key in the Compose file. |

The GitLab image supports embedded configuration through its documented
environment setting. Use it to keep the external URL and advertised SSH port
consistent with the ports you publish. Investigate the relationship among the
external URL, the internal listener, the published host port, and the clone URL
before starting the service.

The three persistent locations have different purposes:

- configuration is needed to reproduce how the instance is configured;
- logs are needed to diagnose startup and application failures; and
- application data contains repositories and database state.

Use paths or named volumes that are unambiguous and will not be swept up by a
Mini-Manticore reset. Account for the host's file permissions and any active
mandatory-access-control mechanism.

## Start and initialize GitLab

Render the Compose configuration before starting it. Resolve syntax errors,
unexpanded variables, invalid mounts, and port collisions before proceeding.

Start the project and observe its logs. GitLab takes longer to initialize than
a small single-process container. A running container is not sufficient proof
that the application is ready.

When the web interface responds:

1. obtain or reset the initial administrator credential without placing it in
   the repository;
2. sign in and replace any temporary credential;
3. create the learner's normal account;
4. decide whether routine work needs administrator privileges rather than
   using the root account by default; and
5. add a public SSH key or create a narrowly scoped access token if your chosen
   Git workflow requires one.

Keep credentials outside tracked files.

## Create the local training project

Create a blank project named **Mini-Manticore Training**. Avoid initializing it
with a second README if the imported repository already has commits.

Transfer the course repository into the project by either:

- adding the local GitLab project as a remote and pushing the existing branch;
  or
- using an import mechanism that preserves the existing commits.

The resulting project must contain the course history, not a single commit made
from an extracted working tree. Set `training` as the default branch. You may
work in a personal branch while keeping the imported branch unchanged.

Prove both a fetch and a push from the host. If using SSH, confirm that the
clone URL includes the nonstandard Git SSH port. If using HTTP, confirm that it
includes the configured web port.

Clone the project back from local GitLab into a separate course working
directory. Confirm that the clone checks out `training` by default and retains
the supplied history. Use this local-GitLab clone for the remaining milestones.

## Defer the runner until the CI milestone

A runner is not required to create GitLab, transfer the repository, or build
the manual stack. Install, register, and prove the host shell runner in
Milestone 10, after the manual deployment, Ansible conversion, and Vault
progression are understood.

## Completion criteria

This milestone is complete only when all of the following are true:

- `gitlab.local` resolves on the host;
- the Compose configuration renders without error;
- the GitLab service becomes ready at the advertised web URL;
- the web and Git SSH ports do not displace host SSH or a Mini-Manticore port;
- configuration, logs, and application data remain after container
  recreation;
- the **Mini-Manticore Training** project preserves the imported history;
- the learner can fetch and push through the chosen Git transport;
- a fresh clone from local GitLab checks out `training` and retains history;
- stopping or recreating GitLab does not stop or delete an unrelated test
  Compose project.

Record the evidence used for each assertion. Screenshots alone are not enough
when a command, log, API response, or repeatable action can demonstrate the
behavior.

## Questions to investigate

- Why must GitLab's advertised external URL agree with its published port?
- Why is the container's SSH port mapped away from host port `22`?
- What state is lost if only GitLab's configuration directory is persistent?
- Which Git operations prove that the repository was transferred intact?

## Vendor references

- [Docker Engine installation](https://docs.docker.com/engine/install/)
- [GitLab in a Docker container](https://docs.gitlab.com/install/docker/installation/)
