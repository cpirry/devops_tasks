provider "aws" {
  region = var.target_account_region

  assume_role {
    role_arn = "arn:aws:iam::${var.target_account_id}:role/tofu-deploy"
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "tofu"
    }
  }
}