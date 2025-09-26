resource "aws_cloudwatch_event_rule" "daily_fetch" {
  name                = "${var.project_prefix}-daily-fetch"
  schedule_expression = var.schedule_cron_utc
}

resource "aws_cloudwatch_event_target" "fetch_target" {
  rule      = aws_cloudwatch_event_rule.daily_fetch.name
  target_id = "lambda"
  arn       = aws_lambda_function.fetch_data.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_data.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_fetch.arn
}
