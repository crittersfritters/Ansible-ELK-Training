# GitLab bootstrap reference

This project is deliberately outside `/var/docker` and outside Ansible's
ownership. It shares the host Docker daemon with Mini-Manticore, so the stack
playbooks must never install, reconfigure, restart, or prune Docker.

The course contract preserves the existing lab instance exactly: GitLab EE
`18.2.0-ee.0`, Compose project/service/container name `gitlab`, canonical URL
`http://gitlab.local:8929`, and advertised Git SSH port `2424`. This is a
reproducible course baseline, not a recommendation to install an old release
on another system. Changing its version or edition is a separate maintainer-led
upgrade and migration exercise.

Before a fresh installation, make `gitlab.local` resolve to `127.0.0.1` and
confirm ports `8929`, `443`, and `2424` are free. Create the canonical project
root and its three persistent bind-mount directories, then install the
reference Compose file there so Compose records `/var/training/gitlab` as the
project working directory:

```bash
sudo install -d -m 0755 \
  /var/training/gitlab \
  /var/training/gitlab/config \
  /var/training/gitlab/logs \
  /var/training/gitlab/data
sudo install -m 0644 \
  bootstrap/gitlab/docker-compose.yml \
  /var/training/gitlab/docker-compose.yml
cd /var/training/gitlab
docker compose config
docker compose up -d
docker logs -f gitlab
```

On SELinux hosts, the `:Z` mount suffixes assign private container labels to
these directories. Inspect the resulting labels and permissions rather than
disabling enforcement.

If `/var/training/gitlab` already contains an installation, do not copy the
reference file over it or start a second project. Back up and inspect the live
Compose file, its rendered model, container image, labels, mounts, and port
bindings first. Reconcile only intentional differences and preserve
`config`, `logs`, and `data`; this course does not require a GitLab upgrade or
an EE-to-CE conversion.

GitLab is ready when the container is healthy and
`http://gitlab.local:8929/users/sign_in` responds. Port `443` is a preserved,
loopback-only course publication. Publishing it does not configure TLS while
`external_url` remains HTTP, so HTTPS is not a bootstrap readiness check.

Retrieve the one-time initial administrator password without copying it into
the repository and replace it immediately. If that temporary file is no
longer present, follow GitLab's documented root-password reset procedure.
Creating the host runner is deliberately deferred to Milestone 10; an existing
runner is not changed by this bootstrap.

On a headless host, forward workstation port 8929 to host loopback over SSH,
map `gitlab.local` to `127.0.0.1` on the workstation, and browse the canonical
URL above. Keep all three Compose publications bound to loopback.

This Compose file is an answer-sheet reference. The training branch specifies
the same observable requirements but leaves the YAML to the learner.
