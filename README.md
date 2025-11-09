# Epidemiology MVP on AWS (Terraform)

Minimal, low-cost, automated pipeline:
- EventBridge (cron) -> Lambda pulls data from an open API -> stores to S3 (`raw/DATE/`).
- Glue Crawler updates schema.
- Query with Athena.

## Prereqs
- Terraform >= 1.5
- AWS account/credentials with permissions to create S3, IAM, Lambda, EventBridge, Glue, Athena.

## Deploy
```bash
cd terraform
terraform init
terraform apply -auto-approve
```
By default it fetches Ukraine COVID historical data daily at 09:00 UTC.
Change variables in `terraform/variables.tf` or via `-var` flags.

## Query (Athena)
- Go to Athena console, choose the created workgroup.
- Set the database to the created Glue DB (printed in Terraform outputs).
- Query the `raw` data (JSON) or add your own simple views.

## Destroy
```bash
terraform destroy
```
(Empty S3 buckets first if you stored data).
