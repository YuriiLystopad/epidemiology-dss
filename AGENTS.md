# Repository Guidelines

## Project Structure & Module Organization
The infrastructure lives in `terraform/`, split into focused files (`lambda.tf`, `event_bridge.tf`, `s3.tf`, etc.) so changes stay localized by service. Lambda source sits in `lambda/fetch_data/lambda_function.py`; Terraform’s `archive_file` data source creates `lambda/fetch_data.zip` during `terraform apply`, so edit the Python and let Terraform rebuild the archive. Helper assets reside in `terraform/scripts/` (cloud-init templates) and `terraform/aws/` (vendored AWS CLI bundle for air-gapped installs). Keep new data assets under S3 at `raw/` or `series/` partitions—never commit generated artifacts.

## Build, Test, and Development Commands
- `terraform fmt -recursive terraform` — normalize HCL formatting before review.
- `terraform init && terraform validate` — set up providers and catch schema drift.
- `terraform plan -out=tfplan` — preview infrastructure deltas; share highlights in PRs.
- `terraform apply tfplan` — deploy reviewed plan; rely on remote state where possible.
- `terraform destroy` — tear down stacks when cleaning environments.
- `python -m compileall lambda/fetch_data` — quick syntax check on the Lambda handler.

## Coding Style & Naming Conventions
Follow Terraform’s two-space indentation and descriptive, hyphenated resource names (e.g., `aws_lambda_function.fetch_data`). Keep variables in `snake_case`; reuse `var.project_prefix` for naming. Python follows PEP 8 with four-space indents, explicit logging, and type-hinted helpers. Use uppercase for environment constants (`BUCKET_NAME`, `DATA_URL`) and prefer small, testable functions inside the handler module.

## Testing Guidelines
Treat `terraform validate` and `terraform plan` as mandatory gates. For Python logic changes, add lightweight unit tests under `lambda/tests/` (pytest recommended) and run `python -m pytest lambda/tests`. When altering S3 schemas, upload a fixture via `aws s3 cp` to a sandbox bucket and query with Athena before promoting changes.

## Commit & Pull Request Guidelines
Adopt Conventional Commit prefixes (`feat:`, `fix:`, `chore:`) as seen in `feat: initial commit`; keep subjects under 72 characters. Each PR should include a summary, linked issue or ticket, `terraform plan` excerpt, and screenshots for UI-facing dashboards. Call out any manual steps (e.g., rotating credentials in `keys.txt`) and confirm secrets remain in AWS Parameter Store or environment variables—never hard-code them.

## Security & Configuration Tips
Treat `keys.txt` as placeholder material only; rotate and load real credentials through AWS Secrets Manager or SSM. When distributing artifacts, ensure buckets enforce least-privilege IAM policies from `iam.tf`. Record cron adjustments in `event_bridge.tf` comments so schedule changes are traceable.
