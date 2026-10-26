# Deployment and evidence checklist

## 1. Bootstrap remote state

Copy the example below, then edit it before running the plan. Keep `github_repository`, `github_owner_id`, `github_repository_id`, and `github_branch` consistent. The example identifies this public repository; a fork needs its own numeric GitHub IDs.

The role trust matches the branch's immutable OIDC subject:

```text
repo:Rakeem08@300660116/aws-serverless-order-processing@1360853051:ref:refs/heads/main
```

See [GitHub's OIDC reference](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims). Custom subject settings must match the actual issued `sub`; the deployment workflow's identity step prints `sub` and `aud` for diagnosis. Do not print or commit the token itself.

Existing local `terraform.tfvars` files need the two numeric ID inputs added before planning. Review and apply the bootstrap trust update before expecting the deployment role to authenticate.

~~~bash
cp infra/bootstrap/terraform.tfvars.example infra/bootstrap/terraform.tfvars
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap fmt -check
terraform -chdir=infra/bootstrap validate
terraform -chdir=infra/bootstrap plan -out=tfplan
terraform -chdir=infra/bootstrap apply tfplan
~~~

Create infra/platform/backend.hcl from the backend_hcl bootstrap output.

## 2. Deploy the platform

~~~bash
cp infra/platform/terraform.tfvars.example infra/platform/terraform.tfvars
terraform -chdir=infra/platform init -backend-config=backend.hcl
terraform -chdir=infra/platform fmt -check
terraform -chdir=infra/platform validate
terraform -chdir=infra/platform plan -out=tfplan
terraform -chdir=infra/platform apply tfplan
~~~

## 3. Authenticate and test

Use scripts/get-token.sh to create a test token, then:

~~~bash
export API_URL="$(terraform -chdir=infra/platform output -raw api_url)"
export ACCESS_TOKEN="REPLACE_ME"
./scripts/smoke-test.sh
~~~

## 4. Evidence worth capturing

- Successful CI run.
- Terraform plan and apply summary.
- First order returns 202.
- Duplicate request returns the same order ID.
- Status changes to PROCESSED.
- Receipt exists in S3.
- CloudWatch dashboard shows accepted and processed orders.
- Failure drill reaches the DLQ and sends an alarm.
- Recovery returns the alarm to OK.
- Final Terraform destroy summary.

Never capture tokens, account numbers, email addresses, state contents, or credentials.

## 5. Cleanup

~~~bash
terraform -chdir=infra/platform destroy
~~~

Keep the backend only if you still need the state history. Otherwise empty its versioned bucket and destroy the bootstrap last.

