terraform {
  required_version = "~> 1.9"

  backend "s3" {
    bucket         = "demo-personal-group1b-tfstate-701935371420"   # YOUR bucket
    key            = "infra/terraform.tfstate"
    region         = "eu-west-1"
    #dynamodb_table = "demo-personal-group1b-tflock"                 # YOUR table
    encrypt        = true
    use_lockfile = true
  }

# new workflow comment
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region

  # Every resource gets these tags without you writing them each time.
  # The Group tag is what makes per-group cost reporting possible.
  default_tags {
    tags = {
      Group     = var.group_name
      Programme = "cloud-personal-work-ff"
      ManagedBy = "terraform"
    }
  }
}
