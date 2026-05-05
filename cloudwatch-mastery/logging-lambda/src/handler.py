import json
import logging
import random
import os

logger = logging.getLogger()

logging_level = os.getenv("LOG_LEVEL", "INFO").upper()
logger.setLevel(logging_level)

ENDPOINTS = ["/api/users", "/api/orders", "/api/products", "/api/health"]

def lambda_handler(event, _context):
    logger.info("Received event: %s", json.dumps(event))

    results = []
    for _ in range(random.randint(3,8)):
        status = random.choices([200, 201, 400, 500], weights=[10, 5, 5, 75])[0]
        latency = random.uniform(50, 3000) if status == 500 else random.uniform(10, 300)
        endpoint = random.choice(ENDPOINTS)

        log_entry = {
            "endpoint": endpoint,
            "status_code": status,
            "latency_ms": round(latency, 2),
            "user_id": f"user_{random.randint(1000, 9999)}",
        }

        if status >= 500:
            logger.error("api_call", extra=log_entry)
        elif status >= 400:
            logger.warning("api_call", extra=log_entry)
        else:
            logger.info("api_call", extra=log_entry)
        results.append(log_entry)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "processed": len(results)
        })
    }