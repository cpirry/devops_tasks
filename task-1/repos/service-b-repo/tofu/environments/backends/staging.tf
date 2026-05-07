terraform {
  backend "s3" {
    bucket         = "my-app-tofu-state"
    key            = "service-b/staging/tofu.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "my-app-tofu-statelock"
    encrypt        = true
  }
}