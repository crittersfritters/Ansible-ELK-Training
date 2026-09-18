# Milestone 10: Learner-authored GitLab pipeline

## Goal

Make a committed configuration change reach the running Mini-Manticore stack
through the local GitLab runner and your Ansible implementation.

## Behavioral requirements

- A push to the intended branch creates a pipeline.
- The shell runner prepares any required Ansible dependencies and invokes the
  committed deployment entry point.
- Deployment failure makes the job fail visibly.
- A failed deployment can be diagnosed and retried without manually copying
  repository content after every commit.
- A full-stack deployment is acceptable. Dependency-aware selection is an
  optional extension, not a completion requirement.

## Completion criteria

- A harmless repository change produces a successful pipeline.
- A deliberate managed configuration change becomes active on the running
  stack through the pipeline.
- A deliberate deployment error produces a failed job with useful evidence.
- Correcting the error and retrying or pushing again succeeds.
- Vault-protected inputs are available without appearing in logs or repository
  plaintext.
- Mini-Manticore deployment does not modify the GitLab Compose project.
- You can identify the runner user, working directory, SSH identity, Ansible
  configuration, and dependency locations used by the job.

## Research prompts

- Which assumptions from an interactive shell do not exist in a runner job?
- Should a job deploy from its checkout or copy content elsewhere, and what are
  the consequences?
- How can concurrent deployments interfere with one another?
- Which file changes truly require a full deployment?
- What would be required to make jobs ordered, serialized, or dependency
  aware?
