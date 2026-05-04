#!/usr/bin/env bash

for i in $(seq 1 20); do
  aws lambda invoke \
  --function-name logging_lambda \
  --payload '{"just_for":"testing"}' \
  --cli-binary-format raw-in-base64-out \
  response.json &
done
wait
echo "Done — 50 invocations complete"