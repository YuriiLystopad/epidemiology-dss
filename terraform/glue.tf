resource "aws_glue_catalog_database" "db" {
  name = replace("${var.project_prefix}_raw_${random_id.suffix.hex}", "-", "_")
}

resource "aws_iam_role" "glue" {
  name               = "${var.project_prefix}-glue-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "glue_policy" {
  statement {
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*"
    ]
  }
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "glue_inline" {
  name   = "${var.project_prefix}-glue-inline"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_policy.json
}

resource "aws_glue_crawler" "raw_crawler" {
  name          = "${var.project_prefix}-raw-crawler-${random_id.suffix.hex}"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.db.name

  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/"
  }

  # Optional: daily schedule 10 minutes after fetch (09:10 UTC)
  schedule = "cron(10 9 * * ? *)"
}
