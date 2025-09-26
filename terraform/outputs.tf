output "raw_bucket" {
  value = aws_s3_bucket.raw.bucket
}

output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results.bucket
}

output "glue_database" {
  value = aws_glue_catalog_database.db.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.wg.name
}

output "lambda_name" {
  value = aws_lambda_function.fetch_data.function_name
}
