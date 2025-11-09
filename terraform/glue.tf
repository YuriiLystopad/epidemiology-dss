# ---------- Glue Database ----------
resource "aws_glue_catalog_database" "db" {
  name = replace("${var.project_prefix}_raw_${random_id.suffix.hex}", "-", "_")
}

# ---------- IAM role for Glue ----------
resource "aws_iam_role" "glue" {
  name = "${var.project_prefix}-glue-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Минимальные права для Glue на S3 и логи
data "aws_iam_policy_document" "glue_policy" {
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
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

# Рекомендуется: managed policy с доступом к Glue Catalog
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# ---------- Таблица для плоского NDJSON с партициями ----------
resource "aws_glue_catalog_table" "epi_series_part" {
  name          = "epi_series_part"
  database_name = aws_glue_catalog_database.db.name
  table_type    = "EXTERNAL_TABLE"

  # Партиция по date (YYYY-MM-DD), которую пишет Lambda в ключе series/date=...
  partition_keys {
    name = "date"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.raw.bucket}/series/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "country"
      type = "string"
    }
    columns {
      name = "cases"
      type = "bigint"
    }
    columns {
      name = "deaths"
      type = "bigint"
    }
    columns {
      name = "recovered"
      type = "bigint"
    }
  }

  parameters = {
    classification = "json"
    EXTERNAL       = "TRUE"
  }
}

# ---------- Один (единственный) краулер с двумя таргетами ----------
resource "aws_glue_crawler" "raw_crawler" {
  name          = "${var.project_prefix}-raw-crawler-${random_id.suffix.hex}"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.db.name

  # исходники
  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/"
  }

  # плоские данные для партиций
  s3_target {
    path = "s3://${aws_s3_bucket.raw.bucket}/series/"
  }

  # Запускаем после Lambda (например, в 09:10 UTC)
  schedule = "cron(10 9 * * ? *)"
}
