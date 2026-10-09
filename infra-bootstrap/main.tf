
terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
  # no backend block. This folder keeps its state locally, on purpose.
}
 
provider "aws" {
  region = var.region
  default_tags {
    tags = { Group = var.group_name, ManagedBy = "terraform" }
  }
}
 
variable "region"      { type = string }
variable "group_name"  { type = string }
variable "github_org"  { type = string }   # internship-cws-cloud
variable "github_repo" { type = string }   # demo-personal-group1b
 
# your own account number, looked up rather than typed
data "aws_caller_identity" "me" {}

# infra-bootstrap/main.tf — the state backend
# S3 bucket names must be globally unique across all of AWS,
# which is why the account number is in it.
resource "aws_s3_bucket" "state" {
  bucket = "${var.group_name}-tfstate-${data.aws_caller_identity.me.account_id}"
}
 
# Versioning means a bad apply can be recovered from. Turn it on.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
 
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
 
# Your state contains a database password. This is not optional.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
 
# Stops two applies running at the same time.
resource "aws_dynamodb_table" "lock" {
  name         = "${var.group_name}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

#open-id-provider
# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
# }


# point to existing open-id

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}


# The read-only plan role
# added to infra-bootstrap/main.tf
 
locals {
  repo = "${var.github_org}/${var.github_repo}"
}
 
data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
 
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
 
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
 
    # pull_request events only. Not main, not any branch.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:pull_request"]
    }
  }
}
 
resource "aws_iam_role" "plan" {
  name               = "${var.group_name}-personal-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}
 
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}


# The deploy role

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
 
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]

      
    }
 
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
 
    # ONE repository. ONE branch. Read this line twice.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:ref:refs/heads/main"]
    }
  }
}
 
resource "aws_iam_role" "deploy" {
  name               = "${var.group_name}-personal-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
}
 
# Too broad, deliberately. See the note below.
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
 
output "plan_role_arn"   { value = aws_iam_role.plan.arn }
output "deploy_role_arn" { value = aws_iam_role.deploy.arn }

