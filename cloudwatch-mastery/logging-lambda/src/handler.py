import json
import logging
import random
import os

logger = logging.getLogger()

logging_level = os.getenv("LOG_LEVEL", "INFO").upper()
logger.setLevel(logging_level)

ENDPOINTS = ["/api/users", "/api/orders", "/api/products", "/api/health"]

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    results = []
    for _ in range(random.randint(3,8)):
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

    return {
        "statusCode": 200,
        "body": json.dumps({
            "processed": len(results)
        })
    }