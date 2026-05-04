

### invoking the lambda
```
aws lambda invoke \
  --function-name logging_lambda \
  --payload '{"just_for":"testing"}' \
  --cli-binary-format raw-in-base64-out \
  response.json 

cat response.json
```

### to view json
```
jq . response.json 
{
  "statusCode": 200,
  "body": "{\"processed\": 8}"
}

# extract just the body and parse it
jq -r .body response.json | jq .
```


### queries on log insights
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 30

fields @message
| parse @message '"level":"*"' as level
| stats count(*) by level
```


how parsing works
```
log line:
[ERROR] user_1234 hit /api/orders -> 500 in 1843ms

parse @message "[*] user_* hit * -> * in *ms" as level, user_id, endpoint, status, latency
| filter status = "500"
| stats count() by endpoint
```

```
log line:
[INFO]       2026-05-04T13:31:37.791Z        76ee7b78-51c4-43fb-9235-0d83925239fe    {"level": "INFO", "endpoint": "/api/users", "status_code": 200, "latency_ms": 23.12, "user_id": "user_9624", "request_id": "76ee7b78-51c4-43fb-9235-0d83925239fe"}

fields @timestamp, endpoint, status_code, latency_ms
| filter status_code >= 500
| stats count() by endpoint

# latency percentiles per endpoint
fields @message, endpoint, latency_ms
| stats avg(latency_ms) as avg_ms,
        pct(latency_ms, 50) as p50,
        pct(latency_ms, 90) as p90,
        pct(latency_ms, 99) as p99
  by endpoint

# error rate over time (great for interviews)
fields @message, status_code
| stats count(*) as total,
    sum(status_code >= 500) as errors,
    (sum(status_code >= 500) / count(*)) * 100 as error_pct
    by bin(5m)

# parse message if log doesnt use json.dump
fields @message, status_code
| parse @message '"user_id": "*"' as user_id   <----- here
| filter status_code >= 500
| stats count(*) as error_count by user_id
| sort error_count desc
| limit 10

# REPORT CloudWatch Logs Insights field that Lambda auto-tags every log event with
Log: 
REPORT RequestId: 76ee7b78-51c4-43fb-9235-0d83925239fe
       Duration: 142.31 ms
       Billed Duration: 143 ms
       Memory Size: 128 MB
       Max Memory Used: 67 MB
       Init Duration: 423.18 ms  

filter @type = "REPORT"
| parse @message "Init Duration: * ms" as init_ms
| stats count(*) as cold_starts,
        avg(init_ms) as avg_init,
        max(init_ms) as max_init
  by bin(1h)
```