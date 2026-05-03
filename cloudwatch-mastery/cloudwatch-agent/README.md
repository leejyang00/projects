

## command ran


```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
  -s
```

restart
```
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/aws-config.json
```

stress test
```
# Install stress tool
sudo yum install -y stress

# Spike CPU for 5 minutes
stress --cpu 2 --timeout 300
stress --vm 1 --vm-bytes 512M --timeout 300
```

This config in `config.json` is saying: 
- "Every 60 seconds, collect memory percentage and disk percentage. Also, tail the /var/log/messages file and ship every new line to a CloudWatch Log Group called /cwlab/ec2/system."


aws cloudwatch get-metric-statistics \
  --namespace CWLab/EC2 \
  --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value=i-0efed42ef25d0d4e2 \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

aws cloudwatch get-metric-statistics \
  --namespace CWLab/EC2 \
  --metric-name disk_used_percent \
  --dimensions Name=InstanceId,Value=i-0efed42ef25d0d4e2 \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average


aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0efed42ef25d0d4e2 \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average


