resource "aws_sns_topic" "cw_instance_alarms" {
  name = "cw-instance-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cw_instance_alarms.arn
  protocol  = "email"
  endpoint  = "bobbybrown.jy@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "CWLab-High-CPU"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.example.id
  }

  alarm_actions = [aws_sns_topic.cw_instance_alarms.arn]
  ok_actions    = [aws_sns_topic.cw_instance_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "CWLab-High-Memory"
  namespace           = "CW-MT-Lab/EC2"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 60
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.example.id
  }

  alarm_actions = [aws_sns_topic.cw_instance_alarms.arn]
}
