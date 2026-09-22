# Curriculum-to-answer traceability

This matrix belongs on the answer branch. It lets maintainers change either
branch without putting implementation paths into learner instructions.

| Milestone | Contract/evidence | Earliest answer state | Validation |
|---|---|---|---|
| 00 Host and GitLab | EE 18.2.0, project/container `gitlab`, ports 8929/443/2424, `/var/training/gitlab` persistence, local clone | GitLab bootstrap commit | semantic Compose check; runtime image, health, UI, and exact port publication |
| 01 Elastic foundation | four distinct object types and durable test document | manual Elastic commit | exact templates, mappings, indices, aliases, data views |
| 02 Sensors | fresh Zeek JSON and Suricata EVE records | sensor guidance commit | readable valid source records |
| 03 Direct path | one event per sensor at the intended index/data view | direct-path commit | native configs and direct end-to-end observation |
| 04 Kafka transition | three topics, repeatable initialization, retained records | Kafka manual commit | topic list, consumer path, broker persistence |
| 05 Mission and Grok | all files under `samples/mission`; expected outcomes YAML | mission manual commit | matching, full, unmatched, and bad-date assertions |
| 06 Manual checkpoint | seven independent projects; GitLab untouched | `course-v1.0-rc1-answer-manual` | complete runtime suite on target host |
| 07 First role | SSH identity, Elasticsearch rebuild, second-run no change | first Ansible-role commit | syntax, reconstruction, drift, idempotence evidence |
| 08 Full conversion | all seven projects and three paths | `course-v1.0-rc1-answer-ansible` | full deploy, native config tests, second-run recap |
| 09 Vault | ignored plaintext then tracked ciphertext | security commit | correct/wrong password tests; history secret audit |
| 10 GitLab CI | protected shell runner applies a pushed change | CI commit / answer tip | path-selection matrix, failure, retry, resource lock |

Before a release, verify that every training criterion still has one observable
answer behavior and that no answer implementation entered any commit reachable
from `training`.
