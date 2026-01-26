output "source_bucket_name" {
  value       = aws_s3_bucket.s3-duke-gluedatacatalog-src.bucket
  description = "Name of the created source bucket."
}

output "source_bucket_arn" {
  value       = aws_s3_bucket.s3-duke-gluedatacatalog-src.arn
  description = "ARN of the created source bucket."
}

output "source_prefix" {
  value       = var.src_s3_prefix
  description = "Prefix used for the source data."
}

output "destination_bucket_name" {
  value       = aws_s3_bucket.s3-duke-gluedatacatalog-dst.bucket
  description = "Name of the created destination bucket."
}

output "destination_bucket_arn" {
  value       = aws_s3_bucket.s3-duke-gluedatacatalog-dst.arn
  description = "ARN of the created destination bucket."
}

output "destination_prefix" {
  value       = var.dst_s3_prefix
  description = "Prefix used for the destination data."
}

output "glue_catalog_database_name" {
  value       = aws_glue_catalog_database.this.name
  description = "Glue database name."
}

output "glue_catalog_database_arn" {
  value       = aws_glue_catalog_database.this.arn
  description = "Glue database ARN."
}

output "glue_crawler_name" {
  value       = aws_glue_crawler.this.name
  description = "Glue crawler name."
}

output "glue_crawler_role_arn" {
  value       = aws_iam_role.glue_role.arn
  description = "IAM role ARN used by the Glue crawler."
}
