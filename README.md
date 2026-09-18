# Manual checkpoint: Kafka sensor path

This checkpoint inserts Kafka between the two Filebeat collectors and the
processing Logstash project. It starts from the proven direct path and retains
the same Elasticsearch destinations.

The six independent projects at this state are Elasticsearch, Kibana, Kafka,
processing Logstash, Zeek Filebeat, and Suricata Filebeat. The mission port
router is added in the next checkpoint.

The direct-path prerequisites still apply, including `curl`, working sensor
logs, localhost aliases, Docker Compose, and `vm.max_map_count=1048576`.

Prepare persistent data directories, then start projects in dependency order:

```bash
mkdir -p elasticsearch/data kibana/data kafka/data \
  filebeat_zeek/data filebeat_suricata/data
sudo chown -R 1000:0 elasticsearch/data kibana/data kafka/data
sudo chmod 0770 elasticsearch/data kibana/data kafka/data

docker compose -f elasticsearch/docker-compose.yml up -d --wait
bash elasticsearch/setup-assets.sh
docker compose -f kibana/docker-compose.yml up -d
until curl -fsS 'http://kibana.local:5601/api/status' | \
  grep -q '"level":"available"'; do sleep 5; done
bash kibana/setup-data-views.sh

docker compose -f kafka/docker-compose.yml up -d kafka
until [ "$(docker inspect -f '{{.State.Health.Status}}' kafka)" = healthy ]; do
  sleep 5
done
docker compose -f kafka/docker-compose.yml up -d --no-deps \
  --force-recreate kafka-topics-init
until [ "$(docker inspect -f '{{.State.Status}}' kafka-topics-init)" = exited ]; do
  sleep 2
done
test "$(docker inspect -f '{{.State.ExitCode}}' kafka-topics-init)" = 0
docker compose -f kafka/docker-compose.yml up -d kafka-ui

docker compose -f logstash_pipeline/docker-compose.yml up -d --wait
docker compose -f filebeat_zeek/docker-compose.yml up -d --wait
docker compose -f filebeat_suricata/docker-compose.yml up -d --wait
```

Verify `zeek-group` and `suricata-group`, then trace a newly generated event
from each source into Kafka and through its consumer to Elasticsearch. Stop
processing Logstash briefly and explain what Kafka retains before resuming it.
