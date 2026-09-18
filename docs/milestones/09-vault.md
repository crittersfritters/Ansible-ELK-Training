# Milestone 09: Vault progression

## Goal

Begin with an understood plaintext credential flow, then encrypt it with
Ansible Vault and make the same encrypted input usable manually and from CI.

## Behavioral requirements

- The initial plaintext working file is local and excluded from commits.
- An example or documented variable contract identifies required keys without
  publishing a credential.
- The learner encrypts the working data only after proving the ordinary
  Ansible variable flow.
- The encrypted file may be committed; its password may not.
- GitLab supplies the password through an appropriately protected CI variable
  and a narrow password-client mechanism.

## Completion criteria

- The unencrypted local arrangement works before conversion.
- Repository history contains no plaintext secret.
- The encrypted content can be inspected and used with the correct password.
- An incorrect password fails without silently falling back to another value.
- Manual Ansible runs use the encrypted data.
- The runner can use the same encrypted data without printing the password.
- You can identify which parts are encryption at rest and which connections
  remain plaintext because of the lab boundary.

## Research prompts

- Why prove the variable flow before adding encryption?
- What does Ansible Vault protect, and what does it not protect?
- How can a shell runner obtain a password without committing or echoing it?
- What is the practical effect of GitLab's masked and protected variable
  settings?
- How would a leaked credential be replaced without rewriting unrelated code?
