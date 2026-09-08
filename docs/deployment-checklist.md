# Deployment and evidence checklist

## 1. Bootstrap remote state

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

