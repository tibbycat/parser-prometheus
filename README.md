# parser-prometheus

Prometheus parser for fluent-bit

I am doing this as a means to push prometheus exported metrics to splunk.
There are probably better ways to do this.
Splunk itself can trivially extract kv data. But as an exercise I attempt to do it in parser-promethus.lua.
I wasn't able to use the logfmt parser, probably because of comma delimiters.

```
# Splunk SPL
|rename fields as _raw|extract kvdelim="=" pairdelim=","
```

Parsing prometheus exporters in two steps

1. scrape and log
2. tail and forward (eg to Splunk)

```
[SERVICE]
    Parsers_File    parser-prometheus.conf

# Step 1 Scrape & log
[INPUT]
    name prometheus_scrape
    host ${POD_NODE}
    port 10255
    tag prometheus.kubelet.log
    metrics_path /metrics
    scrape_interval 300s

[OUTPUT]
    name file
    match prometheus.*
    Path ${LOG_DIR}

# tail and forward
[INPUT]
    Tag             metrics.kubelet
    Name            tail
    Path            ${LOG_DIR}/prometheus.kubelet.log

# Extract metric, fields, & value
[FILTER]
    Name            parser
    Parser          prometheus-metrics
    Match           metrics.*
    Key_Name        log
    Reserve_Data    On
    Preserve_Key    On

# Extract kv from fields
[FILTER]
    Name    lua
    Match   metrics.*
    script  parser-prometheus.lua
    call    parse

[OUTPUT]
    Name            splunk
    Match           metrics.*
    Host            ${SPLUNK_HOST}
    Port            ${SPLUNK_PORT}
    event_index     ${SPLUNK_INDEX}
    Splunk_Token    ${SPLUNK_TOKEN}
    tls             On
    tls.verify      Off

```
