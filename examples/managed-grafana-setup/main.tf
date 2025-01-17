
data "aws_ssoadmin_instances" "this" {}

locals {
  identity_store_id = coalesce(var.identity_store_id, tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0])

  tags = {
    Source = "github.com/aws-observability/terraform-aws-observability-accelerator"
  }
}

resource "aws_identitystore_user" "this" {
  count = length(var.identitystore_admins_info)

  identity_store_id = local.identity_store_id
  display_name      = "${var.identitystore_admins_info[count.index].first_name} ${var.identitystore_admins_info[count.index].last_name}"
  user_name         = var.identitystore_admins_info[count.index].email

  name {
    given_name  = var.identitystore_admins_info[count.index].first_name
    family_name = var.identitystore_admins_info[count.index].last_name
  }

  emails {
    value   = var.identitystore_admins_info[count.index].email
    primary = true
  }

}


resource "aws_grafana_workspace" "this" {
  name                     = var.grafana_workspace_name
  description              = "AWS Observability Accelerator Grafana Workspace"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.this.arn
  data_sources             = ["PROMETHEUS"]
  tags                     = local.tags
}

resource "aws_iam_role" "this" {
  name = "aws-observability-accelerator-grafana"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "grafana.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"]
}


resource "aws_grafana_role_association" "this" {
  count        = length(var.identitystore_admins_info)
  role         = "ADMIN"
  user_ids     = aws_identitystore_user.this[*].user_id
  workspace_id = aws_grafana_workspace.this.id
}
