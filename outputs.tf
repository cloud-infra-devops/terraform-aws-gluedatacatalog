
output "source_bucket_name" {
  value = module.glue_data_catalog.source_bucket_name
}

output "source_bucket_arn" {
  value = module.glue_data_catalog.source_bucket_arn
}

output "source_prefix" {
  value = module.glue_data_catalog.source_prefix
}

output "destination_bucket_name" {
  value = module.glue_data_catalog.destination_bucket_name
}

output "destination_bucket_arn" {
  value = module.glue_data_catalog.destination_bucket_arn
}

output "destination_prefix" {
  value = module.glue_data_catalog.destination_prefix
}

output "glue_catalog_database_name" {
  value = module.glue_data_catalog.glue_catalog_database_name
}

output "glue_catalog_database_arn" {
  value = module.glue_data_catalog.glue_catalog_database_arn
}

output "glue_crawler_name" {
  value = module.glue_data_catalog.glue_crawler_name
}

output "glue_crawler_role_arn" {
  value = module.glue_data_catalog.glue_crawler_role_arn
}
