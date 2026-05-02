# CloudWatch Mastery Program

## A Practitioner's Guide — From Foundation to Expert

This program is designed to be followed sequentially. Each phase builds real AWS resources and then layers CloudWatch observability on top. By the end, you'll have a fully monitored multi-service architecture and deep expertise in every corner of CloudWatch.

**Estimated Duration:** 12–14 weeks (adjustable to your pace)
**Prerequisites:** An AWS account (Free Tier is sufficient for most labs), basic CLI comfort, familiarity with at least one programming language (Python recommended)
**Cost Estimate:** Most exercises fit within Free Tier. Budget ~$5–15/month for resources that don't (detailed monitoring, custom metrics at volume, Synthetics canaries). Always tear down resources after each lab.

---

## PART 1 — STRONG FOUNDATIONS

---

### Phase 1: Understanding the Observability Landscape (Week 1)

**Why this matters:** Before touching CloudWatch, you need a mental model for *why* monitoring exists and what good observability looks like. This prevents you from learning tools in a vacuum.

#### 1.1 — Core Concepts to Study

- The three pillars of observability: metrics, logs, and traces
- The difference between monitoring (known-unknowns) and observability (unknown-unknowns)
- What SLIs, SLOs, and SLAs mean and why they drive alerting strategy
- Mean Time to Detect (MTTD) vs Mean Time to Resolve (MTTR) — how monitoring shortens both
- Where CloudWatch sits in the AWS ecosystem alongside CloudTrail (audit), X-Ray (tracing), AWS Config (compliance), and EventBridge (event routing)

#### 1.2 — CloudWatch Architecture Mental Model

Understand these components and how they connect:

```
┌─────────────────────────────────────────────────────────┐
│                    CLOUDWATCH                           │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │ Metrics   │  │  Logs    │  │ Alarms   │  │Dashbds │ │
│  │           │  │          │  │          │  │        │ │
│  │ Default   │  │ Groups   │  │ Standard │  │Widgets │ │
│  │ Custom    │  │ Streams  │  │ Composite│  │Metric  │ │
│  │ EMF       │  │ Insights │  │ Anomaly  │  │Math    │ │
│  │ HiRes     │  │ Filters  │  │ Detection│  │        │ │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘ │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │Events /  │  │Synthetics│  │Contributor│             │
│  │EventBrdg │  │(Canaries)│  │ Insights  │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

#### 1.3 — Terminology to Internalise

| Term | Definition |
|---|---|
| **Namespace** | A container for metrics (e.g., `AWS/EC2`, `AWS/Lambda`, `Custom/MyApp`) |
| **Metric** | A time-ordered set of data points (e.g., `CPUUtilization`) |
| **Dimension** | A name/value pair that uniquely identifies a metric (e.g., `InstanceId=i-abc123`) |
| **Statistic** | Aggregation applied over a period: `Average`, `Sum`, `Minimum`, `Maximum`, `SampleCount`, `pNN` (percentiles) |
| **Period** | The time granularity for aggregation (60s, 300s, etc.) |
| **Resolution** | Standard (60s) vs High-resolution (1s) |
| **Retention** | Data points age out: 1-sec data → 3 hours, 60-sec → 15 days, 300-sec → 63 days, 3600-sec → 455 days |
| **Metric Filter** | A pattern applied to log data that extracts a metric from log events |
| **Log Group** | A collection of log streams sharing the same retention and access settings |
| **Alarm** | A watch on a single metric that triggers actions when thresholds are breached |

#### 1.4 — Study Resources

- **Read:** AWS CloudWatch Documentation — "What is Amazon CloudWatch?" and "How Amazon CloudWatch Works"
- **Watch:** AWS re:Invent talk — "Observability best practices at Amazon" (search YouTube for the most recent year)
- **Free Course:** AWS Skill Builder — "Introduction to Amazon CloudWatch" (~1 hour)

#### 1.5 — Foundation Check

Before moving on, you should be able to answer:
1. What is the difference between a metric and a log?
2. Why do you need dimensions — what would happen without them?
3. If you publish a custom metric every second, how long before you lose that 1-second granularity?
4. What is the Free Tier allowance for CloudWatch custom metrics and alarms?
5. When would you choose CloudWatch over a third-party tool like Datadog or Grafana?

---

### Phase 2: Your First Monitored Resource — EC2 (Week 2)

**Why this matters:** EC2 is the simplest service to monitor. It gives you immediate, tangible results and teaches the core CloudWatch workflow: resource → metrics → alarm → notification.

#### 2.1 — Build the Infrastructure

**Step 1: Create a VPC (manual or CLI)**
```bash
# Create a VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cw-lab-vpc}]'

# Create a public subnet
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.1.0/24 --availability-zone <your-az>

# Create and attach an internet gateway
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id <vpc-id> --internet-gateway-id <igw-id>

# Create a route table with a public route
aws ec2 create-route-table --vpc-id <vpc-id>
aws ec2 create-route --route-table-id <rtb-id> --destination-cidr-block 0.0.0.0/0 --gateway-id <igw-id>
aws ec2 associate-route-table --route-table-id <rtb-id> --subnet-id <subnet-id>
```

**Step 2: Launch an EC2 instance with detailed monitoring**
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \  # Use latest Amazon Linux 2023 AMI for your region
  --instance-type t3.micro \
  --subnet-id <subnet-id> \
  --monitoring Enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cw-lab-instance}]' \
  --key-name <your-key>
```

**Step 3: Install the CloudWatch Agent**
```bash
# SSH into your instance, then:
sudo yum install -y amazon-cloudwatch-agent

# Create agent config (save as /opt/aws/amazon-cloudwatch-agent/etc/config.json)
```

Agent configuration file:
```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWLab/EC2",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent", "mem_available"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      },
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/cwlab/ec2/system",
            "log_stream_name": "{instance_id}/messages",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/cwlab/ec2/security",
            "log_stream_name": "{instance_id}/secure",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
```

```bash
# Start the agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s
```

**Important:** Your EC2 instance needs an IAM role with the `CloudWatchAgentServerPolicy` managed policy attached.

#### 2.2 — Explore Default vs Custom Metrics

**Exercise 1: Browse default EC2 metrics**
```bash
# List all available metrics for your instance
aws cloudwatch list-metrics --namespace AWS/EC2 --dimensions Name=InstanceId,Value=<instance-id>

# Get CPUUtilization for the last hour
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum
```

**Exercise 2: Compare standard vs detailed monitoring**
Note the difference: standard monitoring = data every 5 minutes, detailed = every 1 minute. Use `--period 60` and observe that you actually get data points.

**Exercise 3: Verify custom metrics from the agent**
```bash
# After 5-10 minutes, check for your custom namespace
aws cloudwatch list-metrics --namespace CWLab/EC2

# You should see mem_used_percent, disk_used_percent, cpu_usage_idle, etc.
```

**Exercise 4: Generate load and watch metrics respond**
```bash
# SSH into instance and install stress
sudo yum install -y stress

# Stress the CPU for 5 minutes
stress --cpu 2 --timeout 300

# In another terminal, watch the metric update
watch -n 30 "aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time \$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average"
```

#### 2.3 — Create Your First Alarm

```bash
# Create an SNS topic for notifications
aws sns create-topic --name cw-lab-alerts
aws sns subscribe --topic-arn <topic-arn> --protocol email --notification-endpoint your@email.com
# Confirm the subscription via the email you receive

# Create a CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "EC2-High-CPU" \
  --alarm-description "CPU exceeds 70% for 2 consecutive periods" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <topic-arn> \
  --ok-actions <topic-arn> \
  --treat-missing-data missing

# Create a memory alarm (from custom metrics)
aws cloudwatch put-metric-alarm \
  --alarm-name "EC2-High-Memory" \
  --namespace CWLab/EC2 \
  --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <topic-arn>
```

**Exercise: Trigger the alarm intentionally**
Use `stress --cpu 2 --vm 1 --vm-bytes 512M --timeout 300` and wait for the email notification. Then stop the stress test and watch the alarm return to OK.

#### 2.4 — Understanding Alarm Configuration Deeply

Spend time understanding these alarm settings — they are the most common source of misconfigurations:

| Setting | What it does | Common mistake |
|---|---|---|
| `evaluation-periods` | How many consecutive periods to evaluate | Setting to 1 causes alarm flapping |
| `datapoints-to-alarm` | How many of the evaluation periods must breach | Often confused with evaluation-periods |
| `treat-missing-data` | What to do when data is absent | `breaching` can trigger false alarms during maintenance |
| `period` | Aggregation window | Must align with your metric's resolution |

**Exercise:** Create an alarm with `evaluation-periods 5` and `datapoints-to-alarm 3` (an "M out of N" alarm). This means 3 out of 5 consecutive periods must breach. This is the industry-standard pattern for reducing noise.

#### 2.5 — Phase 2 Checkpoint

You should now be comfortable with:
- Launching EC2 instances and understanding their default CloudWatch metrics
- Installing and configuring the CloudWatch Agent for custom OS-level metrics
- Using the CLI to query metrics with `get-metric-statistics`
- Creating alarms with SNS notifications
- The difference between standard and detailed monitoring
- Alarm evaluation logic (M out of N, treat missing data)

**Tear down:** Terminate your EC2 instance, delete alarms, delete SNS topic, delete log groups to avoid charges.

---

### Phase 3: Logs Foundations — Ingestion, Structure & Querying (Week 3–4)

**Why this matters:** Metrics tell you *something is wrong*. Logs tell you *what went wrong*. CloudWatch Logs is the single most-used feature in production, and Logs Insights is what separates beginners from practitioners.

#### 3.1 — Build a Log-Generating Application

Create a small application that produces structured logs. This is far more realistic than reading system logs.

**Step 1: Create a Lambda function that generates structured JSON logs**

```python
# lambda_function.py
import json
import logging
import random
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ENDPOINTS = ["/api/users", "/api/orders", "/api/products", "/api/health"]
STATUS_CODES = [200, 200, 200, 200, 200, 201, 400, 404, 500]  # Weighted towards success

def lambda_handler(event, context):
    # Simulate processing multiple requests
    num_requests = random.randint(3, 10)
    results = []

    for _ in range(num_requests):
        endpoint = random.choice(ENDPOINTS)
        status = random.choice(STATUS_CODES)
        latency = random.uniform(5, 2000) if status == 500 else random.uniform(5, 300)
        user_id = f"user_{random.randint(1000, 9999)}"

        log_entry = {
            "timestamp": int(time.time() * 1000),
            "level": "ERROR" if status >= 500 else "WARN" if status >= 400 else "INFO",
            "endpoint": endpoint,
            "method": "GET" if endpoint in ["/api/users", "/api/products", "/api/health"] else "POST",
            "status_code": status,
            "latency_ms": round(latency, 2),
            "user_id": user_id,
            "request_id": context.aws_request_id,
            "message": f"{endpoint} responded with {status} in {latency:.0f}ms"
        }

        logger.info(json.dumps(log_entry))
        results.append(log_entry)

    error_count = sum(1 for r in results if r["status_code"] >= 500)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "processed": len(results),
            "errors": error_count
        })
    }
```

**Step 2: Deploy the Lambda**
```bash
# Zip and create the function
zip function.zip lambda_function.py

aws lambda create-function \
  --function-name cw-lab-api-simulator \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --role <your-lambda-execution-role-arn> \
  --zip-file fileb://function.zip \
  --timeout 30
```

**Step 3: Invoke it repeatedly to generate log data**
```bash
# Invoke 50 times to build up log data
for i in $(seq 1 50); do
  aws lambda invoke --function-name cw-lab-api-simulator /dev/null &
done
wait
echo "Done — 50 invocations complete"
```

#### 3.2 — Log Group and Stream Management

```bash
# View the auto-created log group
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/cw-lab

# Set retention (critical for cost control)
aws logs put-retention-policy \
  --log-group-name /aws/lambda/cw-lab-api-simulator \
  --retention-in-days 14

# List log streams (each Lambda container creates one)
aws logs describe-log-streams \
  --log-group-name /aws/lambda/cw-lab-api-simulator \
  --order-by LastEventTime \
  --descending
```

#### 3.3 — CloudWatch Logs Insights — From Beginner to Advanced

This is a skill you will use almost daily. Practice each of these queries:

**Beginner queries:**
```sql
-- 1. Find all errors in the last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50

-- 2. Count log events per log level
fields @message
| parse @message '"level":"*"' as log_level
| stats count(*) as event_count by log_level

-- 3. Find the slowest requests
fields @timestamp, @message
| parse @message '"latency_ms":*,' as latency
| sort latency desc
| limit 10
```

**Intermediate queries:**
```sql
-- 4. Error rate per endpoint per 5-minute bucket
fields @timestamp, @message
| parse @message '"endpoint":"*"' as endpoint
| parse @message '"status_code":*,' as status
| stats count(*) as total,
        sum(status >= 500) as errors,
        (sum(status >= 500) / count(*)) * 100 as error_pct
  by bin(5m), endpoint
| sort bin asc

-- 5. p50, p90, p99 latency per endpoint
fields @timestamp, @message
| parse @message '"endpoint":"*"' as endpoint
| parse @message '"latency_ms":*,' as latency
| stats avg(latency) as avg_ms,
        pct(latency, 50) as p50,
        pct(latency, 90) as p90,
        pct(latency, 99) as p99
  by endpoint

-- 6. Find users generating the most errors
fields @timestamp, @message
| parse @message '"user_id":"*"' as user_id
| parse @message '"status_code":*,' as status
| filter status >= 500
| stats count(*) as error_count by user_id
| sort error_count desc
| limit 20
```

**Advanced queries:**
```sql
-- 7. Detect latency spikes vs baseline
fields @timestamp, @message
| parse @message '"latency_ms":*,' as latency
| parse @message '"endpoint":"*"' as endpoint
| stats avg(latency) as avg_latency,
        pct(latency, 99) as p99_latency,
        max(latency) as max_latency
  by bin(1m), endpoint
| filter p99_latency > 500

-- 8. Correlation: do errors spike with latency?
fields @timestamp, @message
| parse @message '"status_code":*,' as status
| parse @message '"latency_ms":*,' as latency
| stats sum(status >= 500) as error_count,
        avg(latency) as avg_latency,
        pct(latency, 95) as p95_latency
  by bin(5m)
| sort bin asc

-- 9. Cold start detection for Lambda
filter @type = "REPORT"
| parse @message "Init Duration: * ms" as init_duration
| stats count(*) as cold_starts,
        avg(init_duration) as avg_init_ms,
        max(init_duration) as max_init_ms
  by bin(1h)
```

**Exercise:** Write your own queries for the following scenarios (try before looking at hints):
1. Find the busiest 5-minute window in the last 24 hours
2. Identify which endpoint has the worst p99 latency
3. Find all requests from a specific user_id and calculate their personal error rate
4. Detect time windows where error rate exceeded 10%

#### 3.4 — Metric Filters

Turn log patterns into CloudWatch metrics that you can alarm on:

```bash
# Create a metric filter for 5xx errors
aws logs put-metric-filter \
  --log-group-name /aws/lambda/cw-lab-api-simulator \
  --filter-name "API-5xx-Errors" \
  --filter-pattern '{ $.level = "ERROR" }' \
  --metric-transformations \
      metricName=API5xxCount,metricNamespace=CWLab/API,metricValue=1,defaultValue=0

# Create a metric filter for high latency
aws logs put-metric-filter \
  --log-group-name /aws/lambda/cw-lab-api-simulator \
  --filter-name "API-High-Latency" \
  --filter-pattern '{ $.latency_ms > 1000 }' \
  --metric-transformations \
      metricName=HighLatencyCount,metricNamespace=CWLab/API,metricValue=1,defaultValue=0

# Create a metric filter that extracts the actual latency value
aws logs put-metric-filter \
  --log-group-name /aws/lambda/cw-lab-api-simulator \
  --filter-name "API-Latency" \
  --filter-pattern '{ $.latency_ms = * }' \
  --metric-transformations \
      metricName=RequestLatency,metricNamespace=CWLab/API,metricValue=$.latency_ms
```

Now create alarms on these extracted metrics:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "API-Error-Rate-High" \
  --namespace CWLab/API \
  --metric-name API5xxCount \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-topic-arn> \
  --treat-missing-data notBreaching
```

#### 3.5 — Phase 3 Checkpoint

You should now be comfortable with:
- How log groups and log streams are structured
- Retention policies and their cost implications
- Writing Logs Insights queries from simple filters to aggregations and percentiles
- The `parse` command for extracting fields from structured and unstructured logs
- Metric filters — turning log patterns into metrics
- Alarming on log-derived metrics

---

### Phase 4: Custom Metrics & Metric Math (Week 4–5)

**Why this matters:** Default metrics only cover infrastructure. Your application's business metrics (orders processed, payments failed, queue depth trends) require custom metrics and metric math.

#### 4.1 — Publishing Custom Metrics

**Method 1: AWS CLI**
```bash
# Publish a single data point
aws cloudwatch put-metric-data \
  --namespace "CWLab/BusinessMetrics" \
  --metric-name "OrdersProcessed" \
  --dimensions Environment=Production,Service=OrderAPI \
  --value 42 \
  --unit Count

# Publish a high-resolution metric (1-second)
aws cloudwatch put-metric-data \
  --namespace "CWLab/BusinessMetrics" \
  --metric-name "PaymentLatency" \
  --dimensions Service=PaymentGateway \
  --value 156.3 \
  --unit Milliseconds \
  --storage-resolution 1
```

**Method 2: Python SDK (Boto3)**
```python
import boto3
import random
import time
from datetime import datetime, timezone

cloudwatch = boto3.client('cloudwatch')

def publish_business_metrics():
    """Simulate publishing real business metrics every minute."""
    while True:
        # Simulate order metrics
        orders = random.randint(10, 100)
        failed_payments = random.randint(0, 5)
        avg_order_value = random.uniform(25.0, 150.0)

        cloudwatch.put_metric_data(
            Namespace='CWLab/BusinessMetrics',
            MetricData=[
                {
                    'MetricName': 'OrdersProcessed',
                    'Timestamp': datetime.now(timezone.utc),
                    'Value': orders,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': 'Production'},
                        {'Name': 'Service', 'Value': 'OrderAPI'}
                    ]
                },
                {
                    'MetricName': 'FailedPayments',
                    'Timestamp': datetime.now(timezone.utc),
                    'Value': failed_payments,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': 'Production'},
                        {'Name': 'Service', 'Value': 'PaymentGateway'}
                    ]
                },
                {
                    'MetricName': 'AverageOrderValue',
                    'Timestamp': datetime.now(timezone.utc),
                    'Value': round(avg_order_value, 2),
                    'Unit': 'None',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': 'Production'}
                    ]
                }
            ]
        )
        print(f"Published: {orders} orders, {failed_payments} failures, ${avg_order_value:.2f} AOV")
        time.sleep(60)

publish_business_metrics()
```

**Method 3: Embedded Metric Format (EMF) — best practice for Lambda**
```python
# In your Lambda function, print EMF-structured JSON
import json

def emit_emf_metric(endpoint, status_code, latency_ms):
    """Emit a metric using Embedded Metric Format — no SDK call needed."""
    metric_log = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": "CWLab/API",
                    "Dimensions": [["Endpoint", "StatusCode"]],
                    "Metrics": [
                        {"Name": "RequestLatency", "Unit": "Milliseconds"},
                        {"Name": "RequestCount", "Unit": "Count"}
                    ]
                }
            ]
        },
        "Endpoint": endpoint,
        "StatusCode": str(status_code),
        "RequestLatency": latency_ms,
        "RequestCount": 1
    }
    # Simply printing this structured JSON creates CloudWatch metrics automatically
    print(json.dumps(metric_log))
```

EMF is the recommended approach for Lambda because it avoids the latency and cost of calling the CloudWatch API during function execution.

#### 4.2 — Metric Math

Metric math lets you combine metrics into derived metrics without publishing new ones.

**Exercise: Build these expressions in the CloudWatch console**

```
# Error rate percentage
error_rate = (errors / (errors + successes)) * 100

# Requests per second (from a Sum/period metric)
rps = requests / PERIOD(requests)

# Anomaly detection band
anomaly_band = ANOMALY_DETECTION_BAND(latency, 2)

# Fill missing data points with zero (useful for sparse metrics)
filled = FILL(errors, 0)

# Conditional: alert only during business hours
biz_hours = IF(HOUR(requests) >= 9 AND HOUR(requests) <= 17, error_rate)

# Search across dimensions
all_instance_cpu = SEARCH('{AWS/EC2,InstanceId} MetricName="CPUUtilization"', 'Average', 300)
```

#### 4.3 — Phase 4 Checkpoint

You should be able to:
- Publish custom metrics via CLI, SDK, and Embedded Metric Format
- Explain when to use each method and the cost implications
- Write metric math expressions for derived metrics
- Use SEARCH expressions to aggregate across dimensions
- Understand high-resolution vs standard resolution trade-offs

---

## PART 2 — BUILDING & MONITORING REAL ARCHITECTURES

---

### Phase 5: Lambda + API Gateway Monitoring (Week 5–6)

**Why this matters:** Serverless is the most common modern workload, and its monitoring patterns differ significantly from EC2.

#### 5.1 — Build the Architecture

```
Client → API Gateway → Lambda → DynamoDB
                ↓
           CloudWatch
      (Metrics + Logs + Alarms)
```

**Step 1: Create a DynamoDB table**
```bash
aws dynamodb create-table \
  --table-name cw-lab-orders \
  --attribute-definitions AttributeName=orderId,AttributeType=S \
  --key-schema AttributeName=orderId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**Step 2: Create the Lambda function**
```python
# order_api.py
import json
import boto3
import uuid
import time
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('TABLE_NAME', 'cw-lab-orders'))

def handler(event, context):
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')

    try:
        if http_method == 'POST' and path == '/orders':
            body = json.loads(event.get('body', '{}'))
            order_id = str(uuid.uuid4())

            table.put_item(Item={
                'orderId': order_id,
                'product': body.get('product', 'unknown'),
                'amount': str(body.get('amount', 0)),
                'status': 'created',
                'timestamp': int(time.time())
            })

            # EMF metric for business tracking
            print(json.dumps({
                "_aws": {
                    "Timestamp": int(time.time() * 1000),
                    "CloudWatchMetrics": [{
                        "Namespace": "CWLab/OrderService",
                        "Dimensions": [["Operation"]],
                        "Metrics": [
                            {"Name": "OrderCreated", "Unit": "Count"},
                            {"Name": "OrderValue", "Unit": "None"}
                        ]
                    }]
                },
                "Operation": "CreateOrder",
                "OrderCreated": 1,
                "OrderValue": body.get('amount', 0)
            }))

            return {
                'statusCode': 201,
                'body': json.dumps({'orderId': order_id, 'status': 'created'})
            }

        elif http_method == 'GET' and path.startswith('/orders/'):
            order_id = path.split('/')[-1]
            response = table.get_item(Key={'orderId': order_id})

            if 'Item' not in response:
                return {'statusCode': 404, 'body': json.dumps({'error': 'Order not found'})}

            return {
                'statusCode': 200,
                'body': json.dumps(response['Item'])
            }

        else:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Invalid request'})}

    except Exception as e:
        print(json.dumps({
            "level": "ERROR",
            "error": str(e),
            "request_id": context.aws_request_id
        }))
        return {'statusCode': 500, 'body': json.dumps({'error': 'Internal server error'})}
```

**Step 3: Create API Gateway and deploy**
```bash
# Create REST API
aws apigateway create-rest-api --name cw-lab-order-api --endpoint-configuration types=REGIONAL

# (Wire up resources, methods, and Lambda integration via CLI or Console)
# Enable CloudWatch logging on the API Gateway stage
aws apigateway update-stage \
  --rest-api-id <api-id> \
  --stage-name prod \
  --patch-operations \
    op=replace,path=/*/logging/loglevel,value=INFO \
    op=replace,path=/*/metrics/enabled,value=true
```

#### 5.2 — Key Metrics to Monitor

| Service | Critical Metrics | Why |
|---|---|---|
| Lambda | `Errors`, `Duration`, `Throttles`, `ConcurrentExecutions`, `IteratorAge` (if event-sourced) | Detect failures, cold starts, concurrency limits |
| API Gateway | `5XXError`, `4XXError`, `Latency`, `Count`, `IntegrationLatency` | Separate API errors from backend errors |
| DynamoDB | `ConsumedReadCapacityUnits`, `ConsumedWriteCapacityUnits`, `ThrottledRequests`, `SystemErrors` | Capacity and throttling |

#### 5.3 — Build a Comprehensive Alarm Set

```bash
# Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderAPI-Lambda-Errors" \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=cw-lab-order-api \
  --statistic Sum --period 60 --evaluation-periods 3 \
  --datapoints-to-alarm 2 --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn> --treat-missing-data notBreaching

# Lambda duration alarm (approaching timeout)
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderAPI-Lambda-HighDuration" \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=cw-lab-order-api \
  --extended-statistic p95 --period 300 --evaluation-periods 2 \
  --threshold 5000 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# Lambda throttles alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderAPI-Lambda-Throttled" \
  --namespace AWS/Lambda \
  --metric-name Throttles \
  --dimensions Name=FunctionName,Value=cw-lab-order-api \
  --statistic Sum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# API Gateway 5xx alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderAPI-Gateway-5xx" \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiName,Value=cw-lab-order-api \
  --statistic Sum --period 300 --evaluation-periods 2 \
  --threshold 5 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# DynamoDB throttle alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderDB-Throttled" \
  --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value=cw-lab-orders \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>
```

---

### Phase 6: SNS + SQS + EventBridge — Event-Driven Monitoring (Week 6–7)

**Why this matters:** Modern architectures are event-driven. Monitoring event flow, dead-letter queues, and processing pipelines is an essential skill.

#### 6.1 — Build an Event-Driven Pipeline

```
EventBridge Rule → SQS Queue → Lambda Processor → SNS Notification
                      ↓
                  DLQ (Dead Letter Queue)
```

**Step 1: Create the SQS queues**
```bash
# Dead letter queue first
aws sqs create-queue --queue-name cw-lab-orders-dlq

# Main processing queue with DLQ configured
aws sqs create-queue --queue-name cw-lab-orders-queue \
  --attributes '{
    "VisibilityTimeout": "60",
    "MessageRetentionPeriod": "86400",
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"<dlq-arn>\",\"maxReceiveCount\":\"3\"}"
  }'
```

**Step 2: Create an SNS topic for processed order notifications**
```bash
aws sns create-topic --name cw-lab-order-processed
aws sns subscribe --topic-arn <topic-arn> --protocol email --notification-endpoint your@email.com
```

**Step 3: Create a Lambda processor that reads from SQS**
```python
# order_processor.py
import json
import boto3
import time
import random

sns = boto3.client('sns')
ORDER_PROCESSED_TOPIC = '<your-sns-topic-arn>'

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])

        # Simulate processing with occasional failures
        if random.random() < 0.1:  # 10% failure rate
            print(json.dumps({
                "level": "ERROR",
                "message": "Processing failed",
                "order_id": body.get('order_id'),
                "error": "Simulated processing error"
            }))
            raise Exception("Processing failed — will retry and eventually go to DLQ")

        # Simulate processing time
        processing_time = random.uniform(100, 2000)
        time.sleep(processing_time / 1000)

        # Publish success notification
        sns.publish(
            TopicArn=ORDER_PROCESSED_TOPIC,
            Subject=f"Order {body.get('order_id')} processed",
            Message=json.dumps({
                'order_id': body.get('order_id'),
                'status': 'processed',
                'processing_time_ms': round(processing_time, 2)
            })
        )

        # EMF metrics
        print(json.dumps({
            "_aws": {
                "Timestamp": int(time.time() * 1000),
                "CloudWatchMetrics": [{
                    "Namespace": "CWLab/OrderProcessor",
                    "Dimensions": [["Status"]],
                    "Metrics": [
                        {"Name": "ProcessingTime", "Unit": "Milliseconds"},
                        {"Name": "OrdersProcessed", "Unit": "Count"}
                    ]
                }]
            },
            "Status": "Success",
            "ProcessingTime": processing_time,
            "OrdersProcessed": 1
        }))

    return {"statusCode": 200}
```

**Step 4: Create an EventBridge rule that feeds the pipeline**
```bash
# Create a custom event bus (optional, can use default)
aws events create-event-bus --name cw-lab-orders

# Create a rule matching order events
aws events put-rule \
  --name "order-created-rule" \
  --event-bus-name cw-lab-orders \
  --event-pattern '{
    "source": ["com.cwlab.orders"],
    "detail-type": ["OrderCreated"]
  }'

# Target: send matching events to SQS
aws events put-targets \
  --rule order-created-rule \
  --event-bus-name cw-lab-orders \
  --targets "Id=OrderQueue,Arn=<sqs-queue-arn>"

# Send test events
for i in $(seq 1 20); do
  aws events put-events --entries '[{
    "Source": "com.cwlab.orders",
    "DetailType": "OrderCreated",
    "Detail": "{\"order_id\": \"ord-'$i'\", \"amount\": '$((RANDOM % 200 + 10))'}",
    "EventBusName": "cw-lab-orders"
  }]'
done
```

#### 6.2 — Critical SQS Metrics to Monitor

```bash
# DLQ alarm — messages landing in the dead letter queue means failures
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderDLQ-Messages" \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=cw-lab-orders-dlq \
  --statistic Maximum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# Queue depth growing — processing falling behind
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderQueue-Backlog" \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=cw-lab-orders-queue \
  --statistic Maximum --period 300 --evaluation-periods 3 \
  --threshold 100 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# Message age — messages sitting too long unprocessed
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderQueue-MessageAge" \
  --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=cw-lab-orders-queue \
  --statistic Maximum --period 300 --evaluation-periods 1 \
  --threshold 3600 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>
```

#### 6.3 — SNS Monitoring

```bash
# SNS delivery failures
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderSNS-DeliveryFailures" \
  --namespace AWS/SNS \
  --metric-name NumberOfNotificationsFailed \
  --dimensions Name=TopicName,Value=cw-lab-order-processed \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions <sns-arn>
```

#### 6.4 — EventBridge Monitoring

```bash
# Failed invocations (events matched but target invocation failed)
aws cloudwatch put-metric-alarm \
  --alarm-name "EventBridge-FailedInvocations" \
  --namespace AWS/Events \
  --metric-name FailedInvocations \
  --dimensions Name=RuleName,Value=order-created-rule \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# Dead letter events (events that couldn't be delivered to target)
# ThrottledRules — your rules are being rate-limited
```

#### 6.5 — Composite Alarm: Pipeline Health

```bash
# Only page on-call when multiple things go wrong simultaneously
aws cloudwatch put-composite-alarm \
  --alarm-name "OrderPipeline-Critical" \
  --alarm-rule 'ALARM("OrderDLQ-Messages") AND (ALARM("OrderQueue-Backlog") OR ALARM("OrderAPI-Lambda-Errors"))' \
  --alarm-actions <pagerduty-sns-arn> \
  --alarm-description "Pipeline is both producing errors and messages are landing in DLQ"
```

---

### Phase 7: Dashboards — Operational Visibility (Week 7–8)

**Why this matters:** Dashboards are how teams actually interact with monitoring during incidents and daily operations. A well-designed dashboard can cut incident response time in half.

#### 7.1 — Dashboard Design Principles

Before building, understand the hierarchy:

1. **Service-level dashboard** — the "at a glance" view. Shows SLIs (availability, latency, error rate) for a single service. This is what you look at first during an incident.
2. **Infrastructure dashboard** — resource-level detail (EC2 CPU, memory, disk; RDS connections, IOPS).
3. **Pipeline/workflow dashboard** — shows event flow through a system (EventBridge → SQS → Lambda → SNS).
4. **Business dashboard** — orders per minute, revenue, conversion rate. Non-technical stakeholders use this.

#### 7.2 — Build the Pipeline Dashboard

Create this as a JSON definition and deploy it:

```bash
aws cloudwatch put-dashboard --dashboard-name "OrderPipeline" --dashboard-body file://dashboard.json
```

Your `dashboard.json` should include:
- A markdown header widget explaining what the dashboard shows and who owns it
- Error rate as a number widget (current value, big and bold)
- Lambda duration as a line chart with p50/p90/p99
- SQS queue depth as a line chart
- DLQ message count as a number widget (this should always be 0 — red if not)
- API Gateway 5xx vs 4xx as a stacked area chart
- DynamoDB consumed capacity as a line chart
- An alarm status widget showing all pipeline alarms
- SNS delivery success/failure as a bar chart

**Exercise:** Build this dashboard in the console first (drag and drop), then export it to JSON and learn the JSON structure. Then modify the JSON programmatically and re-import.

#### 7.3 — Dashboard Variables

Use CloudWatch dashboard variables to make a single dashboard work across environments:

```json
{
  "variables": [
    {
      "type": "property",
      "property": "FunctionName",
      "inputType": "select",
      "id": "functionName",
      "label": "Lambda Function",
      "visible": true,
      "search": "{AWS/Lambda,FunctionName}"
    }
  ]
}
```

This lets you switch between dev/staging/prod Lambda functions on a single dashboard.

---

## PART 3 — EXPERT LEVEL

---

### Phase 8: Advanced Patterns (Week 9–10)

**Topics to learn and practice:**

**Anomaly Detection Alarms**
- Let CloudWatch ML learn your metric's normal pattern and alert on deviations
- Ideal for metrics with daily/weekly cycles (traffic patterns, batch job durations)
- Configure the band width (number of standard deviations)

**CloudWatch Synthetics (Canaries)**
- Scripted headless browser or API checks that run on a schedule
- Monitor endpoint availability before your users notice
- Write a canary that hits your API Gateway endpoint every 5 minutes

**Cross-Account Observability with OAM**
- Set up a monitoring account that aggregates metrics/logs/traces from workload accounts
- Essential for multi-account AWS Organizations

**CloudWatch Contributor Insights**
- Identify top contributors to a metric (top IP addresses, top error codes, most active users)
- Analyse DynamoDB throttling to find hot partition keys

**Embedded Metric Format at Scale**
- Design a metric taxonomy (naming conventions, dimension strategy)
- Avoid the custom metric cardinality explosion problem (each unique dimension combination = a separate metric = cost)

---

### Phase 9: Infrastructure as Code (Week 11–12)

**Build the entire monitoring stack from code.**

Choose CloudFormation, CDK, or Terraform (CDK recommended for the best CloudWatch experience) and codify everything you built manually in Phases 2–7:

```
monitoring-stack/
├── lib/
│   ├── alarms/
│   │   ├── lambda-alarms.ts
│   │   ├── sqs-alarms.ts
│   │   ├── dynamodb-alarms.ts
│   │   └── composite-alarms.ts
│   ├── dashboards/
│   │   └── pipeline-dashboard.ts
│   ├── log-groups/
│   │   ├── retention-policies.ts
│   │   └── metric-filters.ts
│   └── monitoring-stack.ts
├── bin/
│   └── app.ts
└── test/
    └── monitoring-stack.test.ts
```

**Key exercises:**
- Deploy the full stack with `cdk deploy`
- Write a reusable construct: `MonitoredLambda` that automatically creates the function + alarms + log group + metric filters
- Write a cost estimator script that counts your custom metrics, log ingestion, and alarm count and estimates monthly cost

---

### Phase 10: Capstone Project (Week 13–14)

Build and fully monitor a production-grade application:

```
Route 53 → CloudFront → ALB → ECS Fargate (x3 tasks)
                                    ↓
                              DynamoDB + ElastiCache
                                    ↓
                        EventBridge → SQS → Lambda → SNS
```

Deliver:
1. CloudWatch Agent on ECS tasks collecting custom app metrics
2. Structured JSON logging with EMF metrics
3. Log groups with appropriate retention and metric filters
4. Alarms covering every service (at least 15 alarms)
5. Composite alarms for reduced noise (at least 3)
6. An anomaly detection alarm on traffic patterns
7. A Synthetics canary checking the health endpoint
8. A service-level dashboard and a pipeline dashboard
9. The entire monitoring stack defined in CDK or Terraform
10. A runbook document for each alarm explaining what triggers it, what to check, and how to remediate

---

## Quick Reference — AWS Free Tier for CloudWatch

| Feature | Free Tier Allowance |
|---|---|
| Basic monitoring metrics | All default metrics for EC2, EBS, ELB, RDS |
| Custom metrics | 10 |
| Alarms | 10 |
| API requests | 1,000,000 per month |
| Log data ingestion | 5 GB per month |
| Log data storage | 5 GB per month |
| Dashboards | 3 (up to 50 metrics each) |
| Synthetics canaries | 100 canary runs per month |
| Contributor Insights rules | 1 rule per month |

Monitor your CloudWatch costs themselves using the `AWS/CloudWatch` and `AWS/Logs` billing metrics.

---

## Recommended Study Order Recap

| Week | Phase | What You Build | CloudWatch Skills Gained |
|---|---|---|---|
| 1 | Observability Concepts | Nothing yet — study only | Mental model, terminology |
| 2 | EC2 Monitoring | VPC + EC2 + CW Agent | Default metrics, custom metrics, basic alarms, SNS |
| 3–4 | Logs | Lambda log generator | Log groups, Logs Insights, metric filters |
| 4–5 | Custom Metrics | Metric publishing scripts | SDK metrics, EMF, metric math |
| 5–6 | Serverless Stack | API GW + Lambda + DynamoDB | Multi-service alarms, percentile alarms |
| 6–7 | Event Pipeline | EventBridge + SQS + SNS + Lambda | Queue monitoring, DLQ alarms, composite alarms |
| 7–8 | Dashboards | Full operational dashboards | Widgets, variables, JSON export |
| 9–10 | Advanced | Canaries, cross-account, anomaly detection | Expert-level features |
| 11–12 | IaC | CDK/Terraform monitoring stack | Codified observability |
| 13–14 | Capstone | Full production architecture | Everything combined |