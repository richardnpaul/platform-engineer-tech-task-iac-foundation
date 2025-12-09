# Copilot Instructions

## Repository Purpose

- This repo is a cloud-agnostic Terragrunt/Terraform scaffold: only state plumbing is implemented, no runtime infra yet (see `README.md`).
- Goal is to prove out remote state + stack layout so new landing zones can be added under `modules/<cloud>/<component>` and wired via `environments/<cloud>/<account>/<stack>/terragrunt.hcl`.

## Architecture Map

- `root.hcl` is the single include file every stack consumes; it selects the backend via `TG_CLOUD`, builds the state key as `${project_name}/${path_relative_to_include()}`, and injects `project_name` + `cloud_provider` inputs.
- `terraform.before_hook.bootstrap_state` always runs `scripts/bootstrap-state.sh <cloud> <state_key> …` on `terragrunt init`; currently only the AWS branch is implemented and it must stay idempotent.
- Stacks such as `environments/aws/root/terragrunt.hcl` only define stack-local locals/inputs (env, region, tags) then `terraform.source` the module under `modules/aws/foundation`.
- Modules follow the `main.tf` + `variables.tf` + `outputs.tf` pattern; copy the placeholder when adding real components so Terragrunt inputs stay consistent.

## Workflow Essentials

- Prereqs: Terraform ≥ 1.5, Terragrunt ≥ 0.52, AWS CLI available for the bootstrap script.
- Typical flow: `export TG_CLOUD=aws` (defaults to AWS), optionally override `TG_STATE_BUCKET`, `TG_STATE_REGION`, `TG_STATE_LOCK_TABLE`, then run `cd environments/aws/root && terragrunt init && terragrunt plan`.
- Every stack gets its own state object because the key includes `path_relative_to_include`; keep folder names meaningful because they become part of the S3/GCS/Azure key path.
- When introducing new clouds, update `backend_definitions` in `root.hcl` plus extend `scripts/bootstrap-state.sh` (or add sibling scripts) and wire them into the hook conditions.

## Coding Conventions

- Module `locals` can summarize intent (see `modules/aws/foundation/main.tf`); keep them descriptive so plans make sense even before resources exist.
- Always pass shared parameters (`environment`, `aws_region`, `tags`) through Terragrunt `inputs`; stacks shouldn't set provider blocks directly.
- Tag maps belong in the environment stack file so multiple modules can reuse them; avoid hard-coding tags in `modules/*`.
- Outputs should emit metadata useful to automation (`module_metadata` example) even if no resources are deployed yet.

## Gotchas & Tips

- The bootstrap script fails fast if AWS CLI is missing or bucket/table names are empty; surface these errors instead of swallowing them when automating CI.
- Non-AWS stacks still call the hook but immediately no-op; once you add bootstrap logic for another cloud, ensure the argument order matches the current call signature.
- Never rename `root.hcl` or remove the include block; every stack relies on `find_in_parent_folders("root.hcl")` and the backend logic will silently break otherwise.
- When copying the sample stack, keep the `locals`/`inputs` structure but change `environment`, `aws_region`, and `tags` to avoid sharing remote state keys unintentionally.
