data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  qs_namespace = "default"
  qs_admin_email = var.qs_admin_email
}

resource "aws_quicksight_user" "author" {
  aws_account_id = data.aws_caller_identity.current.account_id
  email          = local.qs_admin_email
  identity_type  = "QUICKSIGHT"
  namespace      = local.qs_namespace
  user_role      = "AUTHOR"
  user_name      = "qs-author"
}

resource "aws_quicksight_data_source" "athena" {
  aws_account_id = data.aws_caller_identity.current.account_id
  data_source_id = "athena-epi"
  name           = "athena-epi"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = aws_athena_workgroup.wg.name
    }
  }

  permission {
    principal = aws_quicksight_user.author.arn
    actions = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
  }
}

resource "aws_quicksight_data_set" "epi_series_part" {
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "epi-series-part"
  name           = "epi_series_part"
  import_mode    = "DIRECT_QUERY"

  physical_table_map {
    physical_table_map_id = "epi-series-part"

    relational_table {
      data_source_arn = aws_quicksight_data_source.athena.arn

      catalog = "AwsDataCatalog"
      schema  = aws_glue_catalog_database.db.name
      name    = "epi_series_part"

      input_columns {
        name = "date"
        type = "DATETIME"
      }
      input_columns {
        name = "country"
        type = "STRING"
      }
      input_columns {
        name = "cases"
        type = "INTEGER"
      }
      input_columns {
        name = "deaths"
        type = "INTEGER"
      }
    }
  }

  permissions {
    principal = aws_quicksight_user.author.arn
    actions = [
        "quicksight:DescribeDataSet",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:PassDataSet",
        "quicksight:DescribeIngestion",
        "quicksight:ListIngestions",
        "quicksight:UpdateDataSet",
        "quicksight:DeleteDataSet",
        "quicksight:CreateIngestion",
        "quicksight:CancelIngestion",
        "quicksight:UpdateDataSetPermissions"
    ]
  }
}

resource "aws_quicksight_data_set" "epi_ua_daily" {
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "epi-ua-daily"
  name           = "epi_ua_daily"
  import_mode    = "DIRECT_QUERY"

  physical_table_map {
    physical_table_map_id = "ua-daily-sql"

    custom_sql {
      data_source_arn = aws_quicksight_data_source.athena.arn
      name      = "ua_daily_sql"
      sql_query = <<-SQL
        SELECT
          CAST(date AS date) AS dt,
          SUM(cases)  AS cases,
          SUM(deaths) AS deaths
        FROM "${aws_glue_catalog_database.db.name}"."epi_series_part"
        WHERE country = 'Ukraine'
        GROUP BY CAST(date AS date)
        ORDER BY dt
      SQL

      columns {
        name = "dt"
        type = "DATETIME"
      }
      columns {
        name = "cases"
        type = "INTEGER"
      }
      columns {
        name = "deaths"
        type = "INTEGER"
      }
    }
  }

  permissions {
    principal = aws_quicksight_user.author.arn
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
  }
}
