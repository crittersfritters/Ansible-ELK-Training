# Manual checkpoint: direct sensor path

This checkpoint proves the two sensor paths before Kafka is introduced. It is
preserved in answer-sheet history so the later queue transition is visible as
a real architectural change.

Prerequisites are native Zeek JSON logs under `/opt/zeek/logs/current`,
Suricata EVE JSON at `/var/log/suricata/eve.json`, the localhost aliases from
the reference contract, Docker Compose, `curl`, and
`vm.max_map_count=1048576`.

Create four persistent state directories for the five Compose projects, start
Elasticsearch, apply its assets, start Kibana, and wait for it before creating
the data views. Then start processing Logstash before the two collectors:

```bash
mkdir -p elasticsearch/data kibana/data filebeat_zeek/data filebeat_suricata/data
sudo chown -R 1000:0 elasticsearch/data kibana/data
sudo chmod 0770 elasticsearch/data kibana/data

docker compose -f elasticsearch/docker-compose.yml up -d --wait
bash elasticsearch/setup-assets.sh
docker compose -f kibana/docker-compose.yml up -d
until curl -fsS 'http://kibana.local:5601/api/status' | \
  grep -q '"level":"available"'; do sleep 5; done
bash kibana/setup-data-views.sh
docker compose -f logstash_pipeline/docker-compose.yml up -d --wait
docker compose -f filebeat_zeek/docker-compose.yml up -d --wait
docker compose -f filebeat_suricata/docker-compose.yml up -d --wait
```

The direct boundaries are:

```text
Zeek JSON -> Zeek Filebeat -> Beats/5044 -> Logstash zeek -> active-zeek
Suricata EVE -> Suricata Filebeat -> Beats/5045 -> Logstash suricata -> active-suricata
```

Generate a fresh event for each sensor, identify it in its source file, and
trace it into its Elasticsearch alias and Kibana data view. Record Filebeat's
registry behavior before moving to the Kafka checkpoint.
