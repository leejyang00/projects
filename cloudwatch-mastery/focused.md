# CloudWatch — Focused Learning Program

## Interview-Ready in 6 Weeks, with Real-World Projects

This program is designed to get you confidently answering CloudWatch interview questions — not through memorisation, but by building real infrastructure and solving the kinds of problems interviewers actually care about.

**Duration:** 6 weeks
**Structure:** Each week has a concept block (what interviewers ask) and a hands-on block (what makes your answers credible). Weeks 5–6 are two integration projects that tie everything together.

---

## Week 1 — Core Concepts & EC2 Monitoring

### What Interviewers Ask

- "What is CloudWatch and what are its main components?"
- "What's the difference between basic and detailed monitoring?"
- "How would you monitor an EC2 instance's memory usage?"
- "Explain namespaces, metrics, dimensions, and statistics."

### What You Need to Know

CloudWatch has five core pillars — you should be able to explain each in one sentence:

- **Metrics** — time-series data points (CPU, memory, error count, anything you measure)
- **Logs** — centralized log storage with a query engine (Logs Insights)
- **Alarms** — automated watches on metrics that trigger actions when thresholds are crossed
- **Dashboards** — visual displays combining metrics, logs, and alarm status into operational views
- **Events/EventBridge** — event routing that reacts to changes in your AWS environment

Key terminology you must be fluent in:

- **Namespace:** Container grouping related metrics (e.g. `AWS/EC2`, `AWS/Lambda`, or custom like `MyApp/Orders`)
- **Dimension:** A key/value pair that identifies a specific metric instance. `InstanceId=i-abc123` means "CPU for this particular instance." Without dimensions, you can't tell metrics apart.
- **Period:** The time window for aggregation. A 300-second period means each data point represents 5 minutes of data.
- **Statistic:** How data points within a period are summarised — Average, Sum, Min, Max, SampleCount, or percentiles (p50, p90, p99).
- **Resolution:** Standard = 60-second minimum granularity. High-resolution = 1-second. High-res costs more and ages out faster (3 hours at 1-sec granularity).

The critical gap interviewers probe: **EC2 does NOT send memory or disk metrics by default.** You need the CloudWatch Agent for those. This is a very common interview question.

### Hands-On: Build and Monitor an EC2 Instance

**1. Launch an EC2 instance with detailed monitoring**
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --monitoring Enabled \
  --iam-instance-profile Name=CloudWatchAgentRole \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cw-lab}]'
```

Your instance's IAM role needs the `CloudWatchAgentServerPolicy` managed policy.

**2. Install and configure the CloudWatch Agent**

SSH in, then:
```bash
sudo yum install -y amazon-cloudwatch-agent
```

Create `/opt/aws/amazon-cloudwatch-agent/etc/config.json`:
```json
{
  "agent": {
    "metrics_collection_interval": 60
  },
  "metrics": {
    "namespace": "CWLab/EC2",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"]
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
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
```

Start the agent:
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json -s
```

**3. Create your first alarm with SNS notification**
```bash
# Create notification channel
aws sns create-topic --name cw-lab-alerts
aws sns subscribe --topic-arn <topic-arn> --protocol email --notification-endpoint you@email.com

# Alarm on high CPU
aws cloudwatch put-metric-alarm \
  --alarm-name "High-CPU" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --statistic Average \
  --period 60 \
  --evaluation-periods 3 \
  --datapoints-to-alarm 2 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <topic-arn> \
  --treat-missing-data missing
```

**4. Trigger it**
```bash
# SSH in, install and run stress
sudo yum install -y stress
stress --cpu 2 --timeout 300
```

Watch the alarm fire, receive the email, then stop the stress test and watch it return to OK.

### Interview Prep

Practice explaining aloud:
- Why `evaluation-periods 3` and `datapoints-to-alarm 2` (M-out-of-N pattern to reduce false positives)
- Why `treat-missing-data missing` is usually correct (you don't want alarms firing during maintenance windows)
- Why memory needs the agent but CPU doesn't (CPU is visible to the hypervisor; memory is inside the OS)

**Tear down all resources when done.**

---

## Week 2 — Logs, Logs Insights & Metric Filters

### What Interviewers Ask

- "How would you troubleshoot a Lambda that's failing intermittently?"
- "What is CloudWatch Logs Insights and how have you used it?"
- "How do you turn a log pattern into a metric you can alarm on?"
- "What are metric filters?"

### What You Need to Know

**Log structure:** Log Group → Log Streams → Log Events. Lambda creates one log group per function and one stream per execution environment. EC2 sends logs via the agent to groups you define.

**Retention matters for cost.** Logs are stored indefinitely by default. Always set retention (7, 14, 30, or 90 days depending on your needs). This is a common "what would you improve" interview question.

**Metric Filters** let you scan log events for patterns and extract CloudWatch metrics from them. For example, counting every line that contains `ERROR` and publishing it as a metric you can alarm on.

**Logs Insights** is a query language for searching and analysing logs. Interviewers love asking candidates to write queries. The key commands are `fields`, `filter`, `parse`, `stats`, and `sort`.

### Hands-On: Lambda with Structured Logging

**1. Create a Lambda that produces realistic logs**
```python
# api_simulator.py
import json
import logging
import random
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ENDPOINTS = ["/api/users", "/api/orders", "/api/products", "/api/health"]

def lambda_handler(event, context):
    results = []
    for _ in range(random.randint(3, 8)):
        status = random.choices([200, 201, 400, 404, 500], weights=[50, 10, 5, 3, 2])[0]
        latency = random.uniform(50, 3000) if status == 500 else random.uniform(10, 300)
        endpoint = random.choice(ENDPOINTS)

        log_entry = {
            "level": "ERROR" if status >= 500 else "WARN" if status >= 400 else "INFO",
            "endpoint": endpoint,
            "status_code": status,
            "latency_ms": round(latency, 2),
            "user_id": f"user_{random.randint(1000, 9999)}",
            "request_id": context.aws_request_id
        }
        logger.info(json.dumps(log_entry))
        results.append(log_entry)

    return {"statusCode": 200, "body": json.dumps({"processed": len(results)})}
```

Deploy and invoke it 50+ times to build up log data:
```bash
zip function.zip api_simulator.py
aws lambda create-function \
  --function-name cw-lab-api-sim \
  --runtime python3.12 \
  --handler api_simulator.lambda_handler \
  --role <lambda-role-arn> \
  --zip-file fileb://function.zip

# Generate data
for i in $(seq 1 50); do
  aws lambda invoke --function-name cw-lab-api-sim /dev/null &
done
wait
```

**2. Set retention**
```bash
aws logs put-retention-policy \
  --log-group-name /aws/lambda/cw-lab-api-sim \
  --retention-in-days 14
```

**3. Practice these Logs Insights queries**

Start simple, build up:
```sql
-- Find all errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

-- Count by log level
fields @message
| parse @message '"level":"*"' as level
| stats count(*) by level

-- p50, p90, p99 latency per endpoint
fields @message
| parse @message '"endpoint":"*"' as endpoint
| parse @message '"latency_ms":*}' as latency
| stats avg(latency) as avg_ms,
        pct(latency, 50) as p50,
        pct(latency, 90) as p90,
        pct(latency, 99) as p99
  by endpoint

-- Error rate per 5-minute window
fields @message
| parse @message '"status_code":*,' as status
| stats count(*) as total,
        sum(status >= 500) as errors,
        (sum(status >= 500) / count(*)) * 100 as error_pct
  by bin(5m)

-- Top users generating errors
fields @message
| parse @message '"user_id":"*"' as user_id
| parse @message '"status_code":*,' as status
| filter status >= 500
| stats count(*) as error_count by user_id
| sort error_count desc
| limit 10

-- Lambda cold start analysis
filter @type = "REPORT"
| parse @message "Init Duration: * ms" as init_ms
| stats count(*) as cold_starts, avg(init_ms) as avg_init, max(init_ms) as max_init
  by bin(1h)
```

**4. Create a metric filter and alarm on it**
```bash
# Turn ERROR logs into a metric
aws logs put-metric-filter \
  --log-group-name /aws/lambda/cw-lab-api-sim \
  --filter-name "ErrorCount" \
  --filter-pattern '{ $.level = "ERROR" }' \
  --metric-transformations \
      metricName=AppErrorCount,metricNamespace=CWLab/API,metricValue=1,defaultValue=0

# Alarm when errors exceed 5 in 5 minutes
aws cloudwatch put-metric-alarm \
  --alarm-name "API-Errors-High" \
  --namespace CWLab/API \
  --metric-name AppErrorCount \
  --statistic Sum --period 300 \
  --evaluation-periods 2 --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn> \
  --treat-missing-data notBreaching
```

### Interview Prep

Be ready to walk through: "A Lambda is failing 5% of the time. How do you investigate?" Your answer should flow: check the Lambda Errors metric → look at Logs Insights for ERROR entries → parse latency and status patterns → check if it correlates with specific endpoints or users → check downstream dependencies (DynamoDB throttling? API timeouts?).

---

## Week 3 — Custom Metrics, EMF & Alarms Deep Dive

### What Interviewers Ask

- "How do you publish custom metrics?"
- "What is the Embedded Metric Format?"
- "Explain metric math with an example."
- "What's the difference between a standard alarm, a composite alarm, and an anomaly detection alarm?"
- "How would you reduce alert noise?"

### What You Need to Know

**Three ways to publish custom metrics — know when to use each:**

| Method | When to Use | Trade-off |
|---|---|---|
| `put-metric-data` (CLI/SDK) | Standalone scripts, EC2 apps, cron jobs | Adds API call latency; costs per API call |
| CloudWatch Agent | OS-level metrics on EC2/on-prem | Runs as a daemon; needs config file |
| Embedded Metric Format (EMF) | Lambda functions, containerised apps | Best for Lambda — zero API call overhead; metrics extracted from log output |

**EMF is the recommended approach for Lambda.** You simply print a specially structured JSON log line, and CloudWatch automatically extracts metrics from it. No SDK call, no added latency.

**Metric Math** lets you derive new metrics from existing ones without publishing them. Key expressions: error rate (`errors / (errors + successes) * 100`), requests per second (`requests / PERIOD(requests)`), and anomaly bands (`ANOMALY_DETECTION_BAND(metric, 2)`).

**Alarm types:**
- **Standard alarm** — watches one metric against a static threshold
- **Anomaly detection alarm** — uses ML to learn the metric's normal pattern and alerts on deviations (great for traffic patterns with daily/weekly cycles)
- **Composite alarm** — combines multiple alarms with AND/OR logic. This is how you reduce noise: "only page me if errors are high AND the DLQ has messages"

### Hands-On

**1. Publish metrics with EMF from Lambda**
```python
import json
import time

def emit_order_metric(order_value, processing_time_ms, status):
    print(json.dumps({
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [{
                "Namespace": "CWLab/Orders",
                "Dimensions": [["Status"]],
                "Metrics": [
                    {"Name": "OrderValue", "Unit": "None"},
                    {"Name": "ProcessingTime", "Unit": "Milliseconds"},
                    {"Name": "OrderCount", "Unit": "Count"}
                ]
            }]
        },
        "Status": status,
        "OrderValue": order_value,
        "ProcessingTime": processing_time_ms,
        "OrderCount": 1
    }))
```

**2. Build a composite alarm**
```bash
# Individual alarms first
aws cloudwatch put-metric-alarm --alarm-name "Lambda-Errors" ...
aws cloudwatch put-metric-alarm --alarm-name "DLQ-HasMessages" ...

# Composite: only fire when BOTH conditions are true
aws cloudwatch put-composite-alarm \
  --alarm-name "Pipeline-Critical" \
  --alarm-rule 'ALARM("Lambda-Errors") AND ALARM("DLQ-HasMessages")' \
  --alarm-actions <sns-arn>
```

**3. Create an anomaly detection alarm**
```bash
aws cloudwatch put-anomaly-detector \
  --namespace CWLab/Orders \
  --metric-name OrderCount \
  --stat Sum

aws cloudwatch put-metric-alarm \
  --alarm-name "Orders-AnomalyDetection" \
  --namespace CWLab/Orders \
  --metric-name OrderCount \
  --statistic Sum --period 300 \
  --evaluation-periods 3 \
  --threshold-metric-id ad1 \
  --comparison-operator LessThanLowerOrGreaterThanUpperThreshold \
  --metrics '[
    {"Id":"m1","MetricStat":{"Metric":{"Namespace":"CWLab/Orders","MetricName":"OrderCount"},"Period":300,"Stat":"Sum"}},
    {"Id":"ad1","Expression":"ANOMALY_DETECTION_BAND(m1, 2)"}
  ]' \
  --alarm-actions <sns-arn>
```

### Interview Prep

Practice explaining: "How would you design alerting for a system that gets 10x traffic on weekends?" Answer: anomaly detection alarms instead of static thresholds, because a static threshold that works on Tuesday would either miss problems or false-alarm on Saturday.

---

## Week 4 — Dashboards & Operational Visibility

### What Interviewers Ask

- "How do you design a CloudWatch dashboard?"
- "What's the difference between a service dashboard and a business dashboard?"
- "How do you use dashboards during an incident?"

### What You Need to Know

Dashboards serve different audiences and purposes:

- **Service dashboard** — shows SLIs (error rate, latency, availability) for one service. This is what you open first during an incident. Keep it to 6-10 widgets maximum.
- **Infrastructure dashboard** — resource-level detail: CPU, memory, disk, connections, IOPS
- **Pipeline dashboard** — shows event flow: messages in → processing → messages out → DLQ depth
- **Business dashboard** — non-technical: orders per hour, revenue, conversion rate

Widget types to know: line charts (trends), number widgets (current values), gauge widgets (percentage towards limit), alarm status widgets (red/green at a glance), log widgets (recent errors), and markdown widgets (context and runbook links).

### Hands-On

Build a dashboard in the console with at least 8 widgets covering your Lambda + SNS resources from previous weeks. Then export it to JSON:

```bash
aws cloudwatch get-dashboard --dashboard-name MyDashboard
```

Study the JSON structure. Modify it (add a widget, change a metric), and re-import:
```bash
aws cloudwatch put-dashboard --dashboard-name MyDashboard --dashboard-body file://dashboard.json
```

This teaches you to manage dashboards as code — which is how production teams actually do it.

---

## Week 5 — Integration Project 1: E-Commerce Order Processing Pipeline

### The Scenario

You're building an order processing system for an e-commerce platform. Orders come in through an API, get validated and queued, then processed asynchronously. Failed orders go to a dead-letter queue for manual review. The business needs to know: how many orders per minute, what's the error rate, and are we processing orders fast enough?

### Architecture

```
Client
  ↓
API Gateway (REST)
  ↓
Lambda: Order Validator
  ↓ (valid orders)
SQS: order-processing-queue  ──(failures after 3 retries)──→  SQS: order-dlq
  ↓
Lambda: Order Processor
  ↓
DynamoDB: orders-table
  ↓
SNS: order-notifications  →  Email / Slack
```

### Step-by-Step Build

**1. DynamoDB Table**
```bash
aws dynamodb create-table \
  --table-name cw-lab-orders \
  --attribute-definitions AttributeName=orderId,AttributeType=S \
  --key-schema AttributeName=orderId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**2. SQS Queues**
```bash
# Dead letter queue
aws sqs create-queue --queue-name cw-lab-order-dlq

# Main queue with DLQ
aws sqs create-queue --queue-name cw-lab-order-queue \
  --attributes '{
    "VisibilityTimeout":"60",
    "RedrivePolicy":"{\"deadLetterTargetArn\":\"<dlq-arn>\",\"maxReceiveCount\":\"3\"}"
  }'
```

**3. SNS Topic**
```bash
aws sns create-topic --name cw-lab-order-notifications
aws sns subscribe --topic-arn <topic-arn> --protocol email --notification-endpoint you@email.com
```

**4. Lambda: Order Validator**

This Lambda receives API Gateway requests, validates the order, and sends valid orders to SQS.

```python
# order_validator.py
import json
import boto3
import time
import uuid

sqs = boto3.client('sqs')
QUEUE_URL = '<your-queue-url>'

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))

        # Validation
        errors = []
        if 'product' not in body:
            errors.append("Missing 'product'")
        if 'amount' not in body or not isinstance(body.get('amount'), (int, float)):
            errors.append("Missing or invalid 'amount'")
        if body.get('amount', 0) <= 0:
            errors.append("Amount must be positive")

        if errors:
            # EMF: track validation failures
            print(json.dumps({
                "_aws": {
                    "Timestamp": int(time.time() * 1000),
                    "CloudWatchMetrics": [{
                        "Namespace": "CWLab/OrderPipeline",
                        "Dimensions": [["Stage"]],
                        "Metrics": [{"Name": "ValidationFailure", "Unit": "Count"}]
                    }]
                },
                "Stage": "Validator",
                "ValidationFailure": 1
            }))
            return {
                'statusCode': 400,
                'body': json.dumps({'errors': errors})
            }

        # Valid order — send to SQS
        order_id = str(uuid.uuid4())
        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps({
                'order_id': order_id,
                'product': body['product'],
                'amount': body['amount'],
                'submitted_at': int(time.time())
            }),
            MessageAttributes={
                'OrderId': {'DataType': 'String', 'StringValue': order_id}
            }
        )

        # EMF: track successful validation
        print(json.dumps({
            "_aws": {
                "Timestamp": int(time.time() * 1000),
                "CloudWatchMetrics": [{
                    "Namespace": "CWLab/OrderPipeline",
                    "Dimensions": [["Stage"]],
                    "Metrics": [
                        {"Name": "OrderAccepted", "Unit": "Count"},
                        {"Name": "OrderValue", "Unit": "None"}
                    ]
                }]
            },
            "Stage": "Validator",
            "OrderAccepted": 1,
            "OrderValue": body['amount']
        }))

        return {
            'statusCode': 202,
            'body': json.dumps({'order_id': order_id, 'status': 'queued'})
        }

    except Exception as e:
        print(json.dumps({"level": "ERROR", "error": str(e), "request_id": context.aws_request_id}))
        return {'statusCode': 500, 'body': json.dumps({'error': 'Internal error'})}
```

**5. Lambda: Order Processor**

This Lambda is triggered by SQS, processes orders, writes to DynamoDB, and notifies via SNS.

```python
# order_processor.py
import json
import boto3
import time
import random

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
table = dynamodb.Table('cw-lab-orders')
TOPIC_ARN = '<your-sns-topic-arn>'

def lambda_handler(event, context):
    for record in event['Records']:
        order = json.loads(record['body'])
        start_time = time.time()

        try:
            # Simulate processing with 10% failure rate
            if random.random() < 0.10:
                raise Exception(f"Payment gateway timeout for order {order['order_id']}")

            # Simulate variable processing time
            processing_time = random.uniform(100, 1500)
            time.sleep(processing_time / 1000)

            # Write to DynamoDB
            table.put_item(Item={
                'orderId': order['order_id'],
                'product': order['product'],
                'amount': str(order['amount']),
                'status': 'completed',
                'processedAt': int(time.time())
            })

            # Notify via SNS
            sns.publish(
                TopicArn=TOPIC_ARN,
                Subject=f"Order {order['order_id']} completed",
                Message=json.dumps({
                    'order_id': order['order_id'],
                    'status': 'completed',
                    'amount': order['amount']
                })
            )

            # EMF: success metrics
            elapsed = (time.time() - start_time) * 1000
            print(json.dumps({
                "_aws": {
                    "Timestamp": int(time.time() * 1000),
                    "CloudWatchMetrics": [{
                        "Namespace": "CWLab/OrderPipeline",
                        "Dimensions": [["Stage", "Status"]],
                        "Metrics": [
                            {"Name": "ProcessingTime", "Unit": "Milliseconds"},
                            {"Name": "OrderProcessed", "Unit": "Count"}
                        ]
                    }]
                },
                "Stage": "Processor",
                "Status": "Success",
                "ProcessingTime": round(elapsed, 2),
                "OrderProcessed": 1
            }))

        except Exception as e:
            elapsed = (time.time() - start_time) * 1000

            print(json.dumps({
                "level": "ERROR",
                "order_id": order['order_id'],
                "error": str(e),
                "request_id": context.aws_request_id
            }))

            # EMF: failure metrics
            print(json.dumps({
                "_aws": {
                    "Timestamp": int(time.time() * 1000),
                    "CloudWatchMetrics": [{
                        "Namespace": "CWLab/OrderPipeline",
                        "Dimensions": [["Stage", "Status"]],
                        "Metrics": [
                            {"Name": "ProcessingTime", "Unit": "Milliseconds"},
                            {"Name": "ProcessingFailure", "Unit": "Count"}
                        ]
                    }]
                },
                "Stage": "Processor",
                "Status": "Failed",
                "ProcessingTime": round(elapsed, 2),
                "ProcessingFailure": 1
            }))

            # Re-raise so SQS retries (and eventually sends to DLQ)
            raise
```

**6. Wire up API Gateway**

Create a REST API with:
- `POST /orders` → Order Validator Lambda
- `GET /orders/{id}` → a simple lookup Lambda (optional)

Enable detailed CloudWatch metrics on the API Gateway stage.

**7. Generate traffic**
```bash
# Simulate 100 orders
for i in $(seq 1 100); do
  curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/prod/orders \
    -H "Content-Type: application/json" \
    -d "{\"product\": \"widget-$((RANDOM % 10))\", \"amount\": $((RANDOM % 200 + 5))}" &
done
wait

# Send some invalid requests too
for i in $(seq 1 20); do
  curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/prod/orders \
    -H "Content-Type: application/json" \
    -d '{"product": "bad-order"}' &
done
wait
```

### Full Monitoring Stack

**Alarms to create:**

```bash
# 1. Validator Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderValidator-Errors" \
  --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=cw-lab-order-validator \
  --statistic Sum --period 60 --evaluation-periods 3 \
  --datapoints-to-alarm 2 --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn> --treat-missing-data notBreaching

# 2. Processor Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderProcessor-Errors" \
  --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=cw-lab-order-processor \
  --statistic Sum --period 60 --evaluation-periods 3 \
  --datapoints-to-alarm 2 --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn> --treat-missing-data notBreaching

# 3. DLQ has messages (critical — means orders are failing permanently)
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderDLQ-HasMessages" \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=cw-lab-order-dlq \
  --statistic Maximum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# 4. Queue backlog growing (processing falling behind)
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderQueue-Backlog" \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=cw-lab-order-queue \
  --statistic Maximum --period 300 --evaluation-periods 3 \
  --threshold 50 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# 5. Message age (orders waiting too long)
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderQueue-OldMessages" \
  --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=cw-lab-order-queue \
  --statistic Maximum --period 300 --evaluation-periods 1 \
  --threshold 3600 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# 6. API Gateway 5xx rate
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderAPI-5xx" \
  --namespace AWS/ApiGateway --metric-name 5XXError \
  --dimensions Name=ApiName,Value=cw-lab-order-api \
  --statistic Sum --period 300 --evaluation-periods 2 \
  --threshold 5 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# 7. DynamoDB throttling
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderDB-Throttled" \
  --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value=cw-lab-orders \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>

# 8. Composite alarm — pipeline is broken
aws cloudwatch put-composite-alarm \
  --alarm-name "OrderPipeline-Critical" \
  --alarm-rule 'ALARM("OrderDLQ-HasMessages") AND (ALARM("OrderProcessor-Errors") OR ALARM("OrderQueue-Backlog"))' \
  --alarm-actions <sns-arn> \
  --alarm-description "Orders are failing AND accumulating — pipeline is broken"

# 9. SNS delivery failures
aws cloudwatch put-metric-alarm \
  --alarm-name "OrderSNS-DeliveryFailed" \
  --namespace AWS/SNS \
  --metric-name NumberOfNotificationsFailed \
  --dimensions Name=TopicName,Value=cw-lab-order-notifications \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions <sns-arn>
```

**Logs Insights queries for this pipeline:**
```sql
-- End-to-end: find a specific order across both Lambdas
fields @timestamp, @message, @log
| filter @message like /ord-42/
| sort @timestamp asc

-- Processing time distribution
fields @message
| parse @message '"ProcessingTime":*,' as proc_time
| filter proc_time > 0
| stats avg(proc_time) as avg_ms, pct(proc_time, 95) as p95_ms, max(proc_time) as max_ms

-- Failed orders: what went wrong?
fields @timestamp, @message
| filter @message like /ERROR/
| parse @message '"order_id":"*"' as order_id
| parse @message '"error":"*"' as error
| sort @timestamp desc
| limit 20
```

**Dashboard:** Build one with widgets for orders accepted per minute, processing time p50/p90/p99, DLQ depth, queue backlog, Lambda errors, and an alarm status widget.

### What This Teaches You for Interviews

This single project covers 80% of what interviewers ask about:
- Multi-service monitoring (API Gateway, Lambda, SQS, DynamoDB, SNS)
- Custom metrics via EMF
- Dead-letter queue monitoring (a very common interview question)
- Composite alarms for noise reduction
- Metric filters and Logs Insights
- Structured logging best practices

---

## Week 6 — Integration Project 2: Event-Driven Notification System with EventBridge

### The Scenario

Your company has multiple microservices that need to react to events: when a user signs up, when a payment fails, when inventory runs low. Instead of point-to-point integrations, you use EventBridge as a central event bus. CloudWatch monitors the health of the entire event flow.

### Architecture

```
Microservice A ──→                            ──→ Lambda: Welcome Email
                    EventBridge (custom bus)
Microservice B ──→                            ──→ SQS: Payment Retry Queue ──→ Lambda: Retry Processor
                                              ──→ Lambda: Inventory Alert ──→ SNS: Ops Team
```

### Step-by-Step Build

**1. Create the EventBridge bus and rules**
```bash
aws events create-event-bus --name cw-lab-platform

# Rule 1: User signup events → Welcome email Lambda
aws events put-rule \
  --name user-signup-rule \
  --event-bus-name cw-lab-platform \
  --event-pattern '{"source":["com.platform.users"],"detail-type":["UserSignedUp"]}'

# Rule 2: Payment failure events → Retry queue
aws events put-rule \
  --name payment-failure-rule \
  --event-bus-name cw-lab-platform \
  --event-pattern '{"source":["com.platform.payments"],"detail-type":["PaymentFailed"]}'

# Rule 3: Low inventory events → Alert Lambda
aws events put-rule \
  --name low-inventory-rule \
  --event-bus-name cw-lab-platform \
  --event-pattern '{"source":["com.platform.inventory"],"detail-type":["InventoryLow"]}'
```

**2. Create the target Lambdas and SQS queue**

Write simple handler Lambdas for each target (they can just log the event and emit EMF metrics). The payment retry queue should have its own DLQ.

**3. Wire targets to rules**
```bash
aws events put-targets --rule user-signup-rule --event-bus-name cw-lab-platform \
  --targets "Id=WelcomeEmail,Arn=<welcome-lambda-arn>"

aws events put-targets --rule payment-failure-rule --event-bus-name cw-lab-platform \
  --targets "Id=RetryQueue,Arn=<retry-sqs-arn>"

aws events put-targets --rule low-inventory-rule --event-bus-name cw-lab-platform \
  --targets "Id=InventoryAlert,Arn=<inventory-lambda-arn>"
```

**4. Simulate events**
```python
# event_generator.py — run locally or as a Lambda
import boto3
import json
import random
import time

events = boto3.client('events')

event_types = [
    {
        "Source": "com.platform.users",
        "DetailType": "UserSignedUp",
        "Detail": lambda: json.dumps({
            "user_id": f"usr_{random.randint(10000,99999)}",
            "plan": random.choice(["free", "pro", "enterprise"]),
            "region": random.choice(["au", "us", "eu"])
        })
    },
    {
        "Source": "com.platform.payments",
        "DetailType": "PaymentFailed",
        "Detail": lambda: json.dumps({
            "order_id": f"ord_{random.randint(10000,99999)}",
            "amount": round(random.uniform(10, 500), 2),
            "failure_reason": random.choice(["card_declined", "insufficient_funds", "gateway_timeout"]),
            "retry_count": random.randint(0, 2)
        })
    },
    {
        "Source": "com.platform.inventory",
        "DetailType": "InventoryLow",
        "Detail": lambda: json.dumps({
            "product_id": f"prod_{random.randint(100,999)}",
            "current_stock": random.randint(1, 10),
            "reorder_threshold": 15
        })
    }
]

for i in range(200):
    evt = random.choice(event_types)
    events.put_events(Entries=[{
        "Source": evt["Source"],
        "DetailType": evt["DetailType"],
        "Detail": evt["Detail"](),
        "EventBusName": "cw-lab-platform"
    }])
    time.sleep(0.1)

print("Done: 200 events sent")
```

### Monitoring This Architecture

**Key EventBridge metrics:**
```bash
# Events not matching any rule (potential misconfiguration)
# → Monitor FailedInvocations and InvocationsSentToDLQ per rule

aws cloudwatch put-metric-alarm \
  --alarm-name "EventBridge-FailedInvocations" \
  --namespace AWS/Events \
  --metric-name FailedInvocations \
  --dimensions Name=RuleName,Value=payment-failure-rule \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-arn>
```

**Business-level monitoring with EMF:**

In each target Lambda, emit metrics like `WelcomeEmailsSent`, `PaymentRetriesQueued`, `InventoryAlertsTriggered`. These become the business metrics on your dashboard.

**Cross-service Logs Insights query:**
```sql
-- Trace a specific event across all services
fields @timestamp, @message, @log
| filter @message like /ord_12345/
| sort @timestamp asc
```

**Dashboard for this project:**
- Events received per minute by source (line chart)
- Events matched vs failed per rule (stacked bar)
- Payment retry queue depth
- Payment DLQ count (should be 0)
- Lambda errors across all three handlers
- Business metrics: signups/hr, payment failures/hr, inventory alerts/hr
- Alarm status widget

### What This Teaches You for Interviews

- EventBridge monitoring (frequently asked in senior roles)
- Multi-service event flow observability
- The pattern of custom event bus → rules → multiple targets
- How to trace events across a distributed system using logs
- Designing alarms that separate infrastructure problems from business problems

---

## Interview Question Bank

After completing this program, you should be able to answer all of these confidently:

### Concepts
1. What are the five main components of CloudWatch?
2. Why can't you see memory metrics for EC2 by default?
3. What's the difference between a namespace and a dimension?
4. How long does CloudWatch retain metric data at different resolutions?
5. What is the Embedded Metric Format and why would you use it instead of `put-metric-data`?

### Logs
6. How do you investigate a spike in Lambda errors?
7. Write a Logs Insights query to find the p99 latency per endpoint.
8. What's a metric filter and when would you use one?
9. How do you control CloudWatch Logs costs?

### Alarms
10. What does "M out of N" mean in alarm configuration?
11. What are the four options for treating missing data, and when would you use each?
12. What's a composite alarm and why would you use one?
13. When would you use anomaly detection instead of a static threshold?

### Architecture
14. What SQS metrics should you always monitor? (ApproximateNumberOfMessagesVisible, ApproximateAgeOfOldestMessage, and DLQ depth)
15. How do you monitor a dead-letter queue?
16. How would you set up monitoring for an event-driven pipeline?
17. How would you design dashboards for a multi-service architecture?
18. What's the difference between CloudWatch Events and EventBridge?

### Operations
19. How do you reduce alert fatigue? (Composite alarms, M-out-of-N, anomaly detection)
20. How do you manage CloudWatch costs at scale? (Retention policies, metric cardinality, dashboard limits)
21. How would you automate remediation when an alarm fires?
22. How would you set up cross-account monitoring?

---

## Tear-Down Checklist

After each project, delete everything to avoid charges:
- Lambda functions
- API Gateway
- DynamoDB tables
- SQS queues
- SNS topics and subscriptions
- EventBridge rules, targets, and event buses
- CloudWatch alarms, dashboards, log groups
- IAM roles (or keep and reuse)
- EC2 instances, VPCs (if created)