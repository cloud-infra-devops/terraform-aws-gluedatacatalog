# Example usage of the Glue Data Catalog module
module "aws_glue_data_catalog" {
  source               = "git::https://github.com/das-pra-tik/duke-terraform-modules.git//modules/aws_glue_data_catalog"
  glue_catalog_db_name = "duke_glue_catalog_db"
  catalog_table_name   = "duke_iceberg"
  glue_crawler_name    = "duke_glue_crawler"
  crawler_schedule     = "ON_DEMAND"
  # auto_import_schema   = true
  # tables = {
  #   orders = {
  #     columns = [
  #       { name = "order_id", type = "int" },
  #       { name = "customer_id", type = "int" },
  #       { name = "status", type = "string" },
  #       { name = "order_ts", type = "timestamp" }
  #     ]
  #   }

  #   customers = {
  #     columns = [
  #       { name = "customer_id", type = "int" },
  #       { name = "email", type = "string" },
  #       { name = "first_name", type = "string" },
  #       { name = "last_name", type = "string" },
  #       { name = "created_ts", type = "timestamp" }
  #     ]
  #   }

  #   events = {
  #     columns = [
  #       { name = "event_id", type = "bigint" },
  #       { name = "event_ts", type = "timestamp" },
  #       { name = "user_id", type = "string" },
  #       { name = "event_type", type = "string" },
  #       { name = "payload", type = "string" }
  #     ]
  #   }
  # }

  # Recrawl & schema change policies
  recrawl_behavior            = "CRAWL_EVERYTHING"
  schema_change_policy_update = "UPDATE_IN_DATABASE"
  schema_change_policy_delete = "LOG"

  # Lineage and configuration overrides
  crawler_lineage_settings = "ENABLE"
  crawler_configuration = {
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddAndUpdateBehavior = "InheritFromTable" }
    }
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  }

  s3_bucket_versioning = false
  alarm_actions        = [] # e.g., ["arn:aws:sns:us-east-1:123456789012:alerts"]

  # Provide if you want catalog-change alarms and have CloudTrail logs in CWL
  create_glue_cloudtrail_logs = true
  cloudtrail_log_group_name   = "/aws/cloudtrail/glue-logs" # e.g., "/aws/cloudtrail/organization"

  tags = {
    Dept        = "Cloud-Infra-DevOps"
    Owner       = "Duke-Energy"
    environment = "sbx"
    ManagedBy   = "terraform"
    Project     = "AIM-IMA-Data-Product"
    email       = "aws-core-team@duke-energy.com"
  }
}
