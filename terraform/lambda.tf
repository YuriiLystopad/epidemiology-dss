data "archive_file" "fetch_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/fetch_data"
  output_path = "${path.module}/../lambda/fetch_data.zip"
}

resource "aws_lambda_function" "fetch_data" {
  function_name = "${var.project_prefix}-fetch"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.fetch_zip.output_path
  source_code_hash = data.archive_file.fetch_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.raw.bucket
      DATA_URL    = var.data_url
    }
  }

  timeout = 30
}
