# GitLab bootstrap reference

This project is deliberately outside `/var/docker` and outside Ansible's
ownership. It shares the host Docker daemon with Mini-Manticore, so the stack
playbooks must never install, reconfigure, restart, or prune Docker.

Before starting it, create the three bind-mount directories, make
`gitlab.local` resolve to `127.0.0.1`, and confirm ports `8929` and `2224` are
free. Then render and start only this project:

```bash
sudo mkdir -p /var/training/gitlab/{config,logs,data}
docker compose -f bootstrap/gitlab/docker-compose.yml config
docker compose -f bootstrap/gitlab/docker-compose.yml up -d
docker logs -f mini-manticore-gitlab
```

GitLab is ready at `http://gitlab.local:8929` after its application health
checks settle. Retrieve the one-time initial administrator password from the
container without copying it into the repository, replace it immediately, and
follow [the identity and Vault guide](../../docs/identity-and-vault.md) for
runner and SSH setup.

On a headless host, forward workstation port 8929 to host loopback over SSH,
map `gitlab.local` to `127.0.0.1` on the workstation, and browse the canonical
URL above. Keep the Compose publication bound to loopback.

This Compose file is an answer-sheet reference. The training branch specifies
the same observable requirements but leaves the YAML to the learner.
