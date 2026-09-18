# Build the local GitLab environment

## Why this milestone is more explicit

GitLab is the entry point for the rest of the course. You cannot use a local
GitLab project or its CI/CD runner until the service exists, so this milestone
provides a firmer contract than later Mini-Manticore exercises.

You will still write the Compose file yourself. This document identifies the
required pieces and the result to prove; it does not provide completed YAML.

GitLab is bootstrap infrastructure. Keep its Compose project, configuration,
and persistent state separate from the seven Mini-Manticore Compose projects.
Later Ansible work must not manage or remove this project.

## Starting point and supported baseline

Obtain the `training` branch from the maintainer's Git account by cloning it or
copying the branch archive. At this point, the authoritative copy is upstream;
your local GitLab does not exist yet.

The supported path begins on Ubuntu 24.04 LTS. From an administrative learner
account, update the host and install the bootstrap tools:

```bash
sudo apt update
sudo apt full-upgrade
sudo apt install -y ca-certificates curl git openssh-client openssh-server \
  python3 python3-yaml python3-requests ansible-core
sudo systemctl enable --now ssh
```

Install Docker Engine and the Compose plugin from Docker's official Ubuntu
repository rather than relying on a similarly named distribution package:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Verify both commands:

```bash
sudo docker run --rm hello-world
sudo docker compose version
```

Verify the host-wide Ansible installation. A system path is intentional: the
later shell runner must execute the same tools without inheriting a learner's
interactive shell configuration.

```bash
ansible-playbook --version
ansible-galaxy --version
python3 -c 'import yaml, requests; print(yaml.__version__, requests.__version__)'
```

Install Zeek and Suricata later in Milestone 02, not as hidden containers
during this bootstrap.

Before proceeding, the host must have these capabilities:

- Docker Engine and the Docker Compose plugin;
- Git;
- an SSH client and server;
- a hostname entry that resolves `gitlab.local` to the local host; and
- enough available CPU, memory, and disk for GitLab plus the later training
  stack.

If you use another distribution, translate these commands and retain the same
checks. Do not continue until an ordinary test container and a small test
Compose project both run successfully.

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
Mini-Manticore reset. Account for any host access-control or mandatory-access-
control requirements on your distribution.

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

## Create a host shell runner

The GitLab application is containerized, but the CI/CD runner belongs on the
Linux host. This separation lets later jobs use host-installed Ansible and SSH
to reach the dedicated `ansible` account.

Install GitLab Runner in the manner appropriate for the distribution. The
supported package creates and manages the dedicated `gitlab-runner` service
account; verify that it has its own home directory and that the service really
runs as that identity. Then register it against the local GitLab instance.

On the supported Ubuntu host, install the runner from GitLab's package
repository after inspecting its repository-setup script:

```bash
curl -L \
  https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh \
  -o /tmp/gitlab-runner-repository.sh
less /tmp/gitlab-runner-repository.sh
sudo bash /tmp/gitlab-runner-repository.sh
sudo apt install -y gitlab-runner
sudo systemctl enable --now gitlab-runner

sudo -u gitlab-runner -H ansible-playbook --version
sudo -u gitlab-runner -H ansible-galaxy --version
sudo -u gitlab-runner -H python3 -c \
  'import yaml, requests; print(yaml.__version__, requests.__version__)'
```

Use the runner registration command shown by the local GitLab UI. Supply
`http://gitlab.local:8929`, choose the `shell` executor, and use the tag
`mini-manticore-local`. Do not paste the authentication token into a tracked
file or terminal transcript.

The runner must use the `shell` executor. A Docker executor would move job
commands into another container and change the SSH, file, and dependency model
used by this course.

When registering the runner:

- choose project, group, or instance scope deliberately;
- use the current runner authentication-token workflow exposed by your GitLab
  version;
- apply a runner tag only if the jobs will request the same tag;
- decide explicitly whether untagged jobs are accepted; and
- do not store the runner token in the repository.

Do not grant the `gitlab-runner` account unrestricted passwordless `sudo` merely
to make a test pipeline pass. Later deployment jobs should connect through the
separate `ansible` account, where privilege escalation and its credentials are
managed as part of the Ansible and Vault milestones.

## Prove the runner independently

Before introducing Ansible, create the smallest useful CI configuration that
proves the shell runner works. The job should make its execution context
observable without printing secrets. It should let you establish:

- which host and user execute the script;
- what the working directory is;
- whether the expected runner tag is selected; and
- whether a pushed commit creates and completes a pipeline.

Remove temporary diagnostic output that exposes more host detail than the
course needs.

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
- a host-installed shell runner appears online in GitLab;
- a pushed test job runs as `gitlab-runner` and completes successfully; and
- stopping or recreating GitLab does not stop or delete an unrelated test
  Compose project.

Record the evidence used for each assertion. Screenshots alone are not enough
when a command, log, API response, or repeatable action can demonstrate the
behavior.

## Questions to investigate

- Why must GitLab's advertised external URL agree with its published port?
- Why is the container's SSH port mapped away from host port `22`?
- What state is lost if only GitLab's configuration directory is persistent?
- How does a shell executor differ from a Docker executor?
- Which permissions does a deployment runner actually need, and which broad
  permissions merely hide an incomplete design?
- How will the later GitLab job authenticate to the `ansible` account without
  placing a private key or password in the repository?

## Vendor references

- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [GitLab in a Docker container](https://docs.gitlab.com/install/docker/installation/)
- [GitLab Runner Linux packages](https://docs.gitlab.com/runner/install/linux-repository/)
- [Registering a runner](https://docs.gitlab.com/runner/register/)
