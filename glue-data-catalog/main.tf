# Create AWS S3 Buckets
resource "aws_s3_bucket" "s3-duke-gluedatacatalog-src" {
  bucket = "s3-duke-gluedatacatalog-src" # Replace with a globally unique name
  tags   = var.tags
}

resource "aws_s3_bucket" "s3-duke-gluedatacatalog-dst" {
  bucket = "s3-duke-gluedatacatalog-dst" # Replace with a globally unique name
  tags   = var.tags
}

# Create the "directory"
resource "aws_s3_object" "src_s3_directory" {
  bucket       = aws_s3_bucket.s3-duke-gluedatacatalog-src.bucket
  key          = "${var.src_s3_prefix}/"   # Key name must end with a slash
  content_type = "application/x-directory" # Optional, helps the console display it correctly
}
resource "aws_s3_object" "dst_s3_directory" {
  bucket       = aws_s3_bucket.s3-duke-gluedatacatalog-dst.bucket
  key          = "${var.dst_s3_prefix}/"   # Key name must end with a slash
  content_type = "application/x-directory" # Optional, helps the console display it correctly
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.s3-duke-gluedatacatalog-src.bucket
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_versioning" "destination" {
  bucket = aws_s3_bucket.s3-duke-gluedatacatalog-dst.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block_src" {
  bucket = aws_s3_bucket.s3-duke-gluedatacatalog-src.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "public_access_block_dst" {
  bucket = aws_s3_bucket.s3-duke-gluedatacatalog-dst.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Glue Catalog Database
resource "aws_glue_catalog_database" "this" {
  name         = var.glue_catalog_db_name != "" ? lower(var.glue_catalog_db_name) : "${lower(var.name_prefix)}-glue-catalog-db-${lower(var.environment)}"
  description  = var.glue_catalog_db_description
  catalog_id   = var.glue_catalog_id
  location_uri = local.src_s3_uri
  tags         = var.tags
  # # Iceberg-oriented parameters (placeholders; adjust according to your engine/lake setup)
  # parameters = {
  #   classification              = "iceberg"
  #   "table_type"                = "ICEBERG"
  #   "iceberg.enabled"           = "true"
  #   "iceberg.format-version"    = "2"
  #   "iceberg.compression-codec" = "zstd"
  #   "iceberg.catalog"           = "glue"
  #   "iceberg.external.table"    = "true"
  #   "iceberg.partitions.spec"   = "[]"
  #   # Add any engine-specific parameters required by your compute layer (Athena/Spark/EMR/LF)
  # }
  dynamic "create_table_default_permission" {
    iterator = create_table_default_permission
    for_each = length(keys(var.glue_catalog_database_create_table_default_permission)) > 0 ? [var.glue_catalog_database_create_table_default_permission] : []

    content {
      permissions = lookup(create_table_default_permission.value, "permissions", null)

      dynamic "principal" {
        iterator = principal
        for_each = length(keys(lookup(create_table_default_permission.value, "principal", {}))) > 0 ? [lookup(create_table_default_permission.value, "principal", {})] : []

        content {
          data_lake_principal_identifier = lookup(principal.value, "data_lake_principal_identifier", null)
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = []
  }
}

# Creates a Glue database with Iceberg tables on S3
resource "aws_glue_catalog_table" "iceberg" {
  depends_on = [aws_glue_catalog_database.this, aws_glue_crawler.this]
  # count         = var.auto_import_schema ? 0 : 1
  # name          = var.table_name
  for_each      = var.tables
  name          = each.key
  database_name = aws_glue_catalog_database.this.name
  description   = var.table_description
  table_type    = var.table_type

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = "2"
    }
  }
  parameters = var.table_parameters

  storage_descriptor {
    location      = "${local.dst_s3_uri}/${each.key}"
    input_format  = "org.apache.iceberg.mr.hive.HiveIcebergInputFormat"
    output_format = "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat"

    ser_de_info {
      name                  = "iceberg-serde"
      serialization_library = "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
    }

    dynamic "columns" {
      # for_each = var.table_columns
      for_each = each.value.columns
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}

# Classifiers
resource "aws_glue_classifier" "grok" {
  count = local.classifier_enabled.grok ? 1 : 0
  name  = "${var.name_prefix}-grok"
  grok_classifier {
    classification  = "grok"
    grok_pattern    = var.grok_pattern
    custom_patterns = var.grok_custom_patterns
  }
}

resource "aws_glue_classifier" "xml" {
  count = local.classifier_enabled.xml ? 1 : 0
  name  = "${var.name_prefix}-xml"
  xml_classifier {
    classification = "xml"
    row_tag        = var.xml_row_tag
  }
}

resource "aws_glue_classifier" "json" {
  count = local.classifier_enabled.json ? 1 : 0
  name  = "${var.name_prefix}-json"
  json_classifier {
    json_path = var.json_path
  }
}

resource "aws_glue_classifier" "csv" {
  count = local.classifier_enabled.csv ? 1 : 0
  name  = "${var.name_prefix}-csv"
  csv_classifier {
    allow_single_column = var.csv_allow_single_column
    contains_header     = var.csv_contains_header
    delimiter           = var.csv_delimiter
    quote_symbol        = var.csv_quote_symbol
    header              = var.csv_header
  }
}

# Glue crawler
resource "aws_glue_crawler" "this" {
  depends_on    = [aws_glue_catalog_database.this]
  name          = var.glue_crawler_name != "" ? lower(var.glue_crawler_name) : "${lower(var.name_prefix)}-glue-crawler-${lower(var.environment)}"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.this.name
  description   = "Crawler for ${var.glue_catalog_db_name} sourcing ${local.src_s3_uri}"
  classifiers = compact(concat(
    local.classifier_enabled.grok ? [aws_glue_classifier.grok[0].name] : [],
    local.classifier_enabled.xml ? [aws_glue_classifier.xml[0].name] : [],
    local.classifier_enabled.json ? [aws_glue_classifier.json[0].name] : [],
    local.classifier_enabled.csv ? [aws_glue_classifier.csv[0].name] : []
  ))

  schedule     = local.crawler_schedule_expression
  table_prefix = var.glue_crawler_table_prefix
  s3_target {
    path            = "${local.src_s3_uri}/"
    sample_size     = var.crawler_sample_size
    event_queue_arn = var.crawler_event_queue_arn
  }

  schema_change_policy {
    update_behavior = var.schema_change_policy_update
    delete_behavior = var.schema_change_policy_delete
  }

  configuration = jsonencode({
    Version  = 1.0
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  lineage_configuration {
    crawler_lineage_settings = var.crawler_lineage_settings
  }
  recrawl_policy {
    recrawl_behavior = var.recrawl_behavior
  }
  tags = merge(
    {
      Name = var.glue_crawler_name != "" ? lower(var.glue_crawler_name) : "${lower(var.name_prefix)}-glue-crawler-${lower(var.environment)}"
    },
    var.tags
  )
  lifecycle {
    create_before_destroy = true
    ignore_changes        = []
  }
}

resource "aws_glue_trigger" "glue_trigger" {
  name = "${lower(var.name_prefix)}-glue-trigger-${lower(var.environment)}"
  type = var.crawler_schedule
  actions {
    crawler_name = aws_glue_crawler.this.name
  }
}


# CloudWatch Log Groups for crawler and catalog
resource "aws_cloudwatch_log_group" "glue_crawler" {
  name              = "/aws-glue/crawlers/${aws_glue_crawler.this.name}"
  retention_in_days = local.log_retention_in_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "glue_catalog" {
  name              = "/aws-glue/datacatalog/${aws_glue_catalog_database.this.name}"
  retention_in_days = local.log_retention_in_days
  tags              = var.tags
}

# Metric filter for ERROR lines in crawler logs
resource "aws_cloudwatch_log_metric_filter" "crawler_errors" {
  name           = "${var.glue_crawler_name}-errors"
  log_group_name = aws_cloudwatch_log_group.glue_crawler.name
  pattern        = "?ERROR ?Error ?Exception"

  metric_transformation {
    name      = "${var.glue_crawler_name}-error-count"
    namespace = "GlueCrawlerCustom"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "crawler_error_alarm" {
  alarm_name          = "${var.glue_crawler_name}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.crawler_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.crawler_errors.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm on any ERROR logged by the Glue crawler ${var.glue_crawler_name}"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  tags                = var.tags
}

# Optional: CloudTrail-based alarm for Glue Data Catalog delete/update events
resource "aws_cloudwatch_log_metric_filter" "catalog_changes" {
  count          = var.cloudtrail_log_group_name != "" ? 1 : 0
  name           = "${var.glue_catalog_db_name}-catalog-changes"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = glue.amazonaws.com) && (($.eventName = DeleteDatabase) || ($.eventName = DeleteTable) || ($.eventName = UpdateDatabase)) }"

  metric_transformation {
    name      = "${var.glue_catalog_db_name}-catalog-change-count"
    namespace = "GlueCrawlerCustom"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "catalog_change_alarm" {
  count               = var.cloudtrail_log_group_name != "" ? 1 : 0
  alarm_name          = "${var.glue_catalog_db_name}-catalog-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.catalog_changes[0].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.catalog_changes[0].metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm on Glue Data Catalog database/table delete or update events captured in CloudTrail."
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  tags                = var.tags
}
resource "aws_cloudwatch_metric_alarm" "crawler_failed_runs" {
  alarm_name          = "${var.name_prefix}-crawler-failed-runs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedRuns"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when Glue crawler has >=1 failed runs in the last 5 minutes."
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "crawler_time_running" {
  alarm_name          = "${var.name_prefix}-crawler-time-running"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TimeRunning"
  namespace           = "Glue"
  period              = 3600
  statistic           = "Average"
  threshold           = var.time_running_threshold_seconds
  alarm_description   = "Alarm when Glue crawler average run time exceeds threshold."
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# Additional CloudWatch Alarms for Glue Crawler (Catalog coverage for Iceberg tables)
resource "aws_cloudwatch_metric_alarm" "crawler_longest_execution" {
  alarm_name          = "${var.name_prefix}-crawler-longest-execution"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LongestExecutionTime"
  namespace           = "Glue"
  period              = 300
  statistic           = "Maximum"
  threshold           = local.longest_execution_threshold_seconds
  alarm_description   = "Alarm when Glue crawler longest execution time exceeds threshold (seconds)."
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "crawler_succeeded_runs_low" {
  alarm_name          = "${var.name_prefix}-crawler-succeeded-runs-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SucceededRuns"
  namespace           = "Glue"
  period              = local.succeeded_runs_period_seconds
  statistic           = "Sum"
  threshold           = local.succeeded_runs_minimum
  alarm_description   = "Alarm when Glue crawler has fewer successful runs than expected over the evaluation window."
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = var.tags
}

# CloudWatch Alarms for crawler health
resource "aws_cloudwatch_metric_alarm" "crawler_failures" {
  alarm_name          = "${var.name_prefix}-crawler-failures"
  alarm_description   = "Alarm when Glue crawler fails runs."
  namespace           = "AWS/Glue"
  metric_name         = "CrawlersFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = var.alarm_actions
  ok_actions         = var.ok_actions
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "crawler_duration" {
  alarm_name          = "${var.name_prefix}-crawler-duration"
  alarm_description   = "Alarm when Glue crawler duration exceeds threshold."
  namespace           = "AWS/Glue"
  metric_name         = "CrawlTime"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.crawler_duration_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    CrawlerName = aws_glue_crawler.this.name
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = var.alarm_actions
  ok_actions         = var.ok_actions
  tags               = var.tags
}
