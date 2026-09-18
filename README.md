# Manual checkpoint: native sensors and fixtures

This checkpoint retains the manual Elasticsearch and Kibana foundation and adds the host-native data sources that later Filebeat projects will collect.

Install and configure Zeek and Suricata using [the native sensor setup reference](docs/sensor-host-setup.md). Zeek must write newline-delimited JSON beneath `/opt/zeek/logs/current`; Suricata must write EVE JSON to `/var/log/suricata/eve.json`.

Before adding a collector, generate fresh traffic and prove each boundary directly:

```bash
sudo test -d /opt/zeek/logs/current
sudo find /opt/zeek/logs/current -maxdepth 1 -type f -name '*.log' -size +0c
sudo test -s /var/log/suricata/eve.json
sudo tail -n 1 /var/log/suricata/eve.json
```

The sanitized records under `samples/` are deterministic parser and mapping inputs; they do not replace evidence from the running sensors. At this state, no Filebeat or Logstash project exists yet. The next checkpoint connects both sensor paths directly so each collector can be understood before Kafka is inserted.
