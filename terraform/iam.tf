data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_prefix}-lambda-exec-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "AllowS3Write"
    actions = ["s3:PutObject", "s3:PutObjectAcl", "s3:AbortMultipartUpload"]
    resources = [
      "${aws_s3_bucket.raw.arn}/*"
    ]
  }

  statement {
    sid       = "AllowLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.project_prefix}-lambda-inline"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# # ---------- IAM Role for QuickSight ----------
# data "aws_iam_policy_document" "qs_trust" {
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "Service"
#       identifiers = ["quicksight.amazonaws.com"]
#     }
#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "quicksight_service_role" {
#   name               = "aws-quicksight-service-role-v0"
#   assume_role_policy = data.aws_iam_policy_document.qs_trust.json
# }

# data "aws_iam_policy_document" "qs_s3_read" {
#   statement {
#     sid     = "AllowListBuckets"
#     effect  = "Allow"
#     actions = ["s3:ListBucket"]
#     resources = [
#       aws_s3_bucket.raw.arn,
#       aws_s3_bucket.athena_results.arn
#     ]
#   }

#   statement {
#     sid     = "AllowGetObjects"
#     effect  = "Allow"
#     actions = ["s3:GetObject","s3:GetObjectVersion"]
#     resources = [
#       "${aws_s3_bucket.raw.arn}/*",
#       "${aws_s3_bucket.athena_results.arn}/*"
#     ]
#   }
# }

# resource "aws_iam_policy" "qs_s3_read" {
#   name   = "QuicksightS3Read"
#   policy = data.aws_iam_policy_document.qs_s3_read.json
# }

# resource "aws_iam_role_policy_attachment" "qs_attach_s3" {
#   role       = aws_iam_role.quicksight_service_role.name
#   policy_arn = aws_iam_policy.qs_s3_read.arn
# }

# resource "aws_iam_role_policy_attachment" "qs_attach_athena" {
#   role       = aws_iam_role.quicksight_service_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSQuicksightAthenaAccess"
# }
