# Manual checkpoint: Elasticsearch and Kibana foundation

This answer-sheet checkpoint establishes the first two Mini-Manticore Compose projects. It deliberately separates four Elasticsearch concepts: composable index templates, backing indices, write aliases, and Kibana data views.

## Prerequisites

Install Docker Engine with the Compose plugin, make the aliases in [the reference contract](docs/reference-contract.md) resolve locally, and set `vm.max_map_count=1048576`. The containers use host networking and bind unauthenticated listeners only to loopback.

## Deploy the foundation

Create the persistent paths, start Elasticsearch, create its assets, then wait for Kibana before creating data views:

```bash
mkdir -p elasticsearch/data kibana/data
sudo chown -R 1000:0 elasticsearch/data kibana/data
sudo chmod 0770 elasticsearch/data kibana/data

docker compose -f elasticsearch/docker-compose.yml up -d --wait
bash elasticsearch/setup-assets.sh

docker compose -f kibana/docker-compose.yml up -d
until curl -fsS 'http://kibana.local:5601/api/status' | \
  grep -q '"level":"available"'; do sleep 5; done
bash kibana/setup-data-views.sh
```

Inspect the four templates, backing indices, write aliases, and data views before continuing. Re-run both setup scripts and explain why an existing index does not retroactively acquire a newly changed template. Native sensors and their sample records are introduced in the next checkpoint.
