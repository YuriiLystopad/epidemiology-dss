resource "aws_athena_workgroup" "wg" {
  name = "${var.project_prefix}_wg_${random_id.suffix.hex}"
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}
