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

# CloudFront ACM certificates must be created in us-east-1 regardless of
# the distribution's origin region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

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