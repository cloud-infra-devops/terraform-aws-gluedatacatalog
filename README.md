# Terraform module: Glue Data Catalog database, crawler, classifiers, alarms, and source bucket

## Features
- Creates an S3 source bucket (versioned) and sets the Glue database `location_uri` to `s3://bucket/prefix`.
- Creates a Glue Data Catalog database.
- Creates a Glue crawler with optional classifiers (grok, XML, JSON, CSV) and on-demand / periodic scheduling (6h or 12h).
- Exposes recrawl behavior, schema change policy, lineage settings, and full crawler configuration (partition handling, schema grouping) as variables.
- IAM role and policy for the crawler to read S3 and write to CloudWatch Logs.
- CloudWatch log metric + alarm for crawler errors; optional CloudTrail-based alarm for catalog changes.
- Tag support.

## Inputs (key)
- `project_name` (string) - naming seed.
- `glue_database_name` (string), `glue_crawler_name` (string).
- `s3_prefix` (string, default `data/`).
- `bucket_name` (string, optional) – if empty, a name with random suffix is created.
- `crawler_schedule` (`ON_DEMAND`, `EVERY_6_HOURS`, `EVERY_12_HOURS`).
- `classifiers` object of booleans for `grok`, `xml`, `json`, `csv`.
- `recrawl_behavior` (`CRAWL_EVERYTHING`, `CRAWL_NEW_FOLDERS_ONLY`, `CRAWL_EVENT_MODE`).
- `schema_change_policy_update` (`UPDATE_IN_DATABASE`, `LOG`), `schema_change_policy_delete` (`LOG`, `DELETE_FROM_DATABASE`, `DEPRECATE_IN_DATABASE`).
- `crawler_lineage_settings` (`ENABLE`, `DISABLE`).
- `crawler_configuration` (map, jsonencoded) – defaults to:
  ```hcl
  {
    Version = 1.0
    CrawlerOutput = { Partitions = { AddAndUpdateBehavior = "InheritFromTable" } }
    Grouping      = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  }
  ```
- `alarm_actions` (list of ARNs).
- `cloudtrail_log_group_name` (string, optional) – required only if you want the catalog-change alarm.

## Notes
- Glue crawlers automatically publish logs to `/aws-glue/crawlers`. The module creates the log group with retention and alarms on any `ERROR`/`Exception` lines.
- Glue Data Catalog itself does not emit metrics; the optional catalog-change alarm relies on CloudTrail logs. Provide a CloudTrail log group that captures Glue events to enable it.
- `crawler_configuration` is passed through `jsonencode`, so you can override partition handling, grouping policy, schema grouping, etc.

## Outputs
- `source_bucket_name`, `source_prefix`
- `glue_database_name`, `glue_crawler_name`
- `crawler_role_arn`

## Example
See `examples/basic/main.tf`.