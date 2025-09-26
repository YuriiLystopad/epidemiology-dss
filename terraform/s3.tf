resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_prefix}-raw-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_prefix}-athena-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_sse" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
