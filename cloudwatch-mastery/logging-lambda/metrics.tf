
# metric filter
resource "aws_cloudwatch_log_metric_filter" "count_errors" {
  name           = "CountErrors"
  pattern        = "{ $.level = \"ERROR\" }"
  log_group_name = aws_cloudwatch_log_group.logger.name

  apply_on_transformed_logs = false

  metric_transformation {
    name          = "EventCount"
    namespace     = "LGLM/Metrics"
    value         = "1"
    default_value = 0
    
    # dimensions = {
    #   endpoint = "$.endpoint"
    # }
  }
}

resource "aws_cloudwatch_log_metric_filter" "count_high_latency" {
  name           = "CountHighLatency"
  pattern        = "{ $.latency_ms >= 1000 }"
  log_group_name = aws_cloudwatch_log_group.logger.name

  apply_on_transformed_logs = false

  metric_transformation {
    name          = "HighLatencyCount"
    namespace     = "LGLM/Metrics"
    value         = "1"
    default_value = 0
    
    # dimensions = {
    #   endpoint = "$.endpoint"
    # }
  }
}