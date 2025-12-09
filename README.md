# Platform Engineering IaC Foundation

Bootstrap Terraform + Terragrunt layout that keeps the infrastructure-as-code stack cloud-agnostic while starting with AWS remote state (S3 + DynamoDB locks). The repository contains no runtime infrastructure modules yet—only the plumbing required to expand safely.

## Layout

```
.
├── root.hcl                     # Terragrunt root with multi-cloud state + before_hook bootstrapper
├── environments/
│   ├── aws/root/        # Sample stack wired into Terragrunt
│   ├── gcp/                     # Placeholder for future landing zones
│   └── azure/                   # Placeholder for future landing zones
├── modules/
│   ├── aws/foundation/             # No-op module showing wiring conventions
│   ├── gcp/
│   └── azure/
└── scripts/bootstrap-state.sh   # Ensures state backends exist before terraform init
```

## Remote State Strategy

- Select the cloud by exporting `TG_CLOUD` (`aws`, `gcp`, `azure`). Defaults to AWS.
- State configuration lives in `root.hcl` as a provider map. Each entry declares backend-specific attributes.
- State keys follow `${project_name}/${path_relative_to_include()}/terraform.tfstate`, so every stack gets an isolated object.
- `terraform.before_hook` invokes `scripts/bootstrap-state.sh` during `terragrunt init` to lazily create the state backend. Currently implemented for AWS (S3 bucket + DynamoDB table). The hook is a no-op for other clouds until their bootstrappers are added.

### AWS Defaults

| Variable | Default | Purpose |
| --- | --- | --- |
| `TG_STATE_BUCKET` | `iac-foundation-tf-state` | S3 bucket for terraform state |
| `TG_STATE_LOCK_TABLE` | `iac-foundation-tf-locks` | DynamoDB table for locking |
| `TG_STATE_REGION` | `eu-west-1` | Region for bucket/table |

Override values via env vars or by editing `root.hcl`.

## Usage

1. Ensure dependencies: Terraform ≥ 1.5, Terragrunt ≥ 0.52, AWS CLI installed and configured (for the bootstrap script).
   - You will need to run `aws login` to have credentials from the root account to do the initial boostrap.
2. Export the desired cloud variables, for example:
   ```bash
   export TG_CLOUD=aws
   export TG_STATE_BUCKET=my-shared-terraform-state
   export TG_STATE_REGION=eu-west-1
   export TG_STATE_LOCK_TABLE=my-terraform-locks
   ```
3. From the sample stack folder run Terragrunt:
   ```bash
   cd environments/aws/root
   terragrunt init
   terragrunt plan
   ```
   The plan is empty because the module is a placeholder, but the command flow validates the wiring and state backend creation.
4. Add additional stacks by copying the sample directory and pointing `terraform.source` at new modules under `modules/<cloud>/<component>`.

## Extending to Other Clouds

- Populate `modules/gcp` or `modules/azure` with landing zone modules and create matching `environments/<cloud>/.../terragrunt.hcl` files that include `root.hcl`.
- Implement provider-specific bootstrap logic inside `scripts/bootstrap-state.sh` (or additional scripts) and wire them via conditionals similar to the AWS block.
- Update the `backend_definitions` map in `root.hcl` to set real state bucket/container names once provisioned.

## Notes

- `scripts/bootstrap-state.sh` must be executable (`chmod +x scripts/bootstrap-state.sh`).
- The script is intentionally idempotent and safe to run repeatedly.
- Keep credentials out of the repo; leverage environment variables, AWS profiles, or secret stores managed by your automation pipeline.
