# Answer-sheet checkpoints

The answer history is staged so learners can compare behavior at the point
where a concept first becomes concrete. Use `git show <tag>` or a detached
worktree; do not copy a whole solution tree into learner work.

| Course phase | Reference location |
|---|---|
| Host and GitLab bootstrap | Early answer history plus `bootstrap/gitlab` at the answer tip |
| Elasticsearch and Kibana | Manual-history commits preceding the manual tag |
| Sensor installation and direct collection | Manual-history commits preceding Kafka insertion |
| Kafka sensor paths and mission Grok | `course-v1.0-rc1-answer-manual` |
| First automated service | Ansible-history commit following the manual tag |
| All seven projects through Ansible | `course-v1.0-rc1-answer-ansible` |
| Vault, dependency-aware CI, validation, operations | `course-v1.0-rc1-answer` |
| Matching learner curriculum | `course-v1.0-rc1-training` |

The RC tags mean static validation passed but target-host runtime validation is
still pending. They are immutable. After the full Linux-host, idempotence,
sensor, GitLab, and CI gates pass, create new final `course-v1.0-*` tags rather
than moving these.

The manual checkpoint contains concrete Compose projects and setup scripts. The
final answer tip contains their Ansible-managed equivalents instead of keeping
two independently drifting implementations in one working tree.

To inspect without disturbing current work:

```bash
git worktree add ../mini-manticore-manual course-v1.0-rc1-answer-manual
```

Remove that worktree with Git after comparison. A branch ZIP is only a snapshot
and cannot expose these intermediate commits; use the Git bundle when course
history matters.
