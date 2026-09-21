# Milestone 00: Host and GitLab bootstrap

## Goal

Prepare one Linux host, run GitLab as an independent Compose project, and make
the training repository usable from that instance.

## Behavioral requirements

- The host can run Compose projects and act as an Ansible controller.
- SSH is available for the later dedicated Ansible account.
- GitLab has a stable local hostname and does not take the host's normal SSH
  port away from system administration.
- GitLab configuration, logs, and application data persist outside a disposable
  container layer.
- The training repository can be pushed to and cloned from local GitLab.

## Create the GitLab Compose project

This bootstrap is the only course area that provides configuration-level
guidance. Write the Compose file yourself; a finished file is not supplied.
Follow [the GitLab bootstrap guide](../gitlab-bootstrap.md) for the new-host
procedure. The checklist below is the milestone summary.

1. Create a directory used only for the GitLab Compose project.
2. Define one GitLab service from a deliberate, recorded image version.
3. Configure GitLab's external URL to match the local hostname you added to
   host name resolution.
4. Publish a browser port and a distinct Git-over-SSH host port. Keep the host's
   existing SSH service reachable.
5. Persist GitLab's configuration, logs, and application data separately. The
   container paths normally used by the omnibus image are `/etc/gitlab`,
   `/var/log/gitlab`, and `/var/opt/gitlab`.
6. Add a restart policy and account for GitLab's startup time and resource use.
7. Render or validate the Compose model before starting it.
8. Start GitLab, follow its startup state, obtain the initial administrator
   credential through the documented image procedure, and sign in.
9. Recreate the GitLab container and prove that the project and account remain.
10. Create a blank **Mini-Manticore Training** project, push the supplied
    branches, make `training` the default, and clone it back from local GitLab.

Do not place Mini-Manticore services in this Compose project. Do not make the
future Mini-Manticore Ansible playbooks responsible for GitLab.

## Completion criteria

- Docker and Compose can start and inspect a test workload.
- GitLab is reachable by its selected hostname.
- GitLab data survives container recreation.
- Git push and clone work against the local instance.
- The local project uses `training` as its default branch.
- You can identify the GitLab project directory and the future
  Mini-Manticore work directory as separate administrative boundaries.

## Research prompts

- Which GitLab image edition and version are suitable for an isolated lab?
- Why must the external URL agree with how clients reach GitLab?
- What survives a container recreation, and why?
- Which host resources does GitLab require before the rest of the stack starts?
