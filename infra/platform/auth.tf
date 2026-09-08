resource "aws_cognito_user_pool" "customers" {
  name = "${local.name}-customers"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "${local.name}-api-client"
  user_pool_id = aws_cognito_user_pool.customers.id

  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation               = true
  explicit_auth_flows                   = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  supported_identity_providers          = ["COGNITO"]
  access_token_validity                 = 60
  id_token_validity                     = 60
  refresh_token_validity                = 1
  auth_session_validity                 = 3

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
