#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${USER_POOL_ID:?Set USER_POOL_ID}"
: "${USER_POOL_CLIENT_ID:?Set USER_POOL_CLIENT_ID}"
: "${TEST_USERNAME:?Set TEST_USERNAME}"
: "${TEST_PASSWORD:?Set TEST_PASSWORD}"

aws cognito-idp admin-create-user \
  --region "$AWS_REGION" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_USERNAME" \
  --temporary-password "$TEST_PASSWORD" \
  --message-action SUPPRESS >/dev/null 2>&1 || true

aws cognito-idp admin-set-user-password \
  --region "$AWS_REGION" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_USERNAME" \
  --password "$TEST_PASSWORD" \
  --permanent

aws cognito-idp initiate-auth \
  --region "$AWS_REGION" \
  --client-id "$USER_POOL_CLIENT_ID" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters "USERNAME=$TEST_USERNAME,PASSWORD=$TEST_PASSWORD" \
  --query 'AuthenticationResult.AccessToken' \
  --output text

