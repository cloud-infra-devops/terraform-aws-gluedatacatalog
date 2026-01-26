# Example usage of the Glue Data Catalog module
module "glue_data_catalog" {
  source = "../"

  glue_catalog_db_name = "duke_glue_catalog_db"
  glue_crawler_name    = "duke_glue_crawler"
  # auto_import_schema   = false
  crawler_schedule = "ON_DEMAND"
  tables = {
    orders = {
      columns = [
        { name = "order_id", type = "int" },
        { name = "customer_id", type = "int" },
        { name = "status", type = "string" },
        { name = "order_ts", type = "timestamp" }
      ]
    }

    customers = {
      columns = [
        { name = "customer_id", type = "int" },
        { name = "email", type = "string" },
        { name = "first_name", type = "string" },
        { name = "last_name", type = "string" },
        { name = "created_ts", type = "timestamp" }
      ]
    }

    events = {
      columns = [
        { name = "event_id", type = "bigint" },
        { name = "event_ts", type = "timestamp" },
        { name = "user_id", type = "string" },
        { name = "event_type", type = "string" },
        { name = "payload", type = "string" }
      ]
    }
  }
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

  alarm_actions = [] # e.g., ["arn:aws:sns:us-east-1:123456789012:alerts"]

  # Provide if you want catalog-change alarms and have CloudTrail logs in CWL
  cloudtrail_log_group_name = "" # e.g., "/aws/cloudtrail/organization"

  tags = {
    environment = "sbx"
    Project     = "advanced-app"
    email       = "aws-core-team@duke-energy.com"
    ManagedBy   = "terraform"
  }
}
