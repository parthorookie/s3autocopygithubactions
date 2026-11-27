# S3 Auto-Copy with Terraform and GitHub Actions

This project deploys an AWS Lambda function and an S3 event notification using Terraform. When an `.mp4` object is uploaded to the existing source bucket (default `temp`), Lambda copies it to the existing destination bucket (default `perm`) under the same object key.

Both buckets must be in the same AWS Region and should already exist. The workflow authenticates with AWS access keys stored as GitHub Actions secrets. For improved security, use a dedicated IAM user with limited permissions and rotate its access keys regularly. OIDC is generally preferred when available because it avoids long-lived keys.

## Files

- `main.tf` — AWS resources and remote Terraform state backend
- `variables.tf` — configurable bucket, region, and Lambda names
- `outputs.tf` — deployment outputs
- `lambda_function.py` — object-copy handler
- `.github/workflows/deploy.yml` — validate, plan, and apply workflow

## Before you start

1. Push this project to a GitHub repository on the `main` branch.
2. Confirm `temp` and `perm` exist in the selected Region and are accessible by your AWS account.
3. Create a separate, dedicated S3 bucket for Terraform state. It must exist before the workflow runs. Enable versioning and block public access on this state bucket. Do not use `temp` or `perm` as the state bucket.
4. Create a dedicated IAM user for GitHub Actions, and grant it the permissions needed to manage the Lambda, its execution role/policy, the source bucket notification, and the Terraform state bucket. It also needs read/describe access to the existing S3 buckets. Scope permissions to the required resources where practical. Create an access key for this user.
5. In GitHub, open **Settings → Secrets and variables → Actions** and add the following repository variables:

   | Variable | Example |
   |---|---|
   | `AWS_REGION` | `ap-south-1` |
   | `SOURCE_BUCKET` | `temp` |
   | `DESTINATION_BUCKET` | `perm` |
   | `LAMBDA_FUNCTION_NAME` | `s3-auto-copy-lambda` |
   | `TF_STATE_BUCKET` | `my-unique-terraform-state-bucket` |

   Add these repository **secrets**:
   - `AWS_ACCESS_KEY_ID` — access key ID for the dedicated IAM user.
   - `AWS_SECRET_ACCESS_KEY` — secret access key for that user.


   Never commit AWS credentials to the repository or put them in Terraform files. The Region must match the Region of both buckets and the state bucket. Replace example names with your actual names.

## Run the workflow

Commit and push to `main`, or use **Actions → Deploy S3 Auto-Copy → Run workflow**.

The workflow runs `terraform fmt`, `terraform init`, `terraform validate`, `terraform plan`, and `terraform apply`. Review and protect changes to the workflow and Terraform files; this workflow automatically applies changes on matching pushes to `main`.

## Test it

Upload an MP4:

```bash
aws s3 cp video.mp4 s3://temp/video.mp4
```

Verify the destination:

```bash
aws s3 ls s3://perm/
```

Check Lambda logs:

```bash
aws logs tail /aws/lambda/s3-auto-copy-lambda --follow
```

## Important notes

- S3 notification suffix filters are case-sensitive. The current notification matches `.mp4` only. If you need `.MP4`, add a second notification filter and ensure the bucket notification configuration remains consolidated.
- `aws_s3_bucket_notification` manages the bucket's notification configuration. If `temp` already has S3 notifications, incorporate them into the same Terraform resource/configuration before applying.
- This example copies objects up to 5 GB with `CopyObject`. Larger objects need multipart copy logic.
- S3 events are at-least-once and may be duplicated. The operation is repeatable for the same key, but a newer upload to the same key can overwrite the destination.
- If `perm` uses SSE-KMS, grant the Lambda execution role the necessary KMS permissions. If bucket policies restrict access, update them accordingly.
- GitHub Actions uses an S3 backend for persistent Terraform state. Create the state bucket before running the workflow. State locking behavior depends on the Terraform version/backend configuration; do not run concurrent applies from other systems.

- This project does not create or delete `temp` or `perm`; it references existing buckets.
