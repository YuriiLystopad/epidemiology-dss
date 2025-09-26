variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "project_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "epi-mvp"
}

variable "data_url" {
  description = "Public API endpoint to fetch data from"
  type        = string
  default     = "https://disease.sh/v3/covid-19/historical/Ukraine?lastdays=all"
}

variable "schedule_cron_utc" {
  description = "EventBridge cron expression in UTC (cron(minutes hours day-of-month month day-of-week year))"
  type        = string
  default     = "cron(0 9 * * ? *)" # every day at 09:00 UTC
}
