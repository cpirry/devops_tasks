variable "name" {
  description = "The name of the secret"
  type        = string
}

variable "secret_string" {
  description = "Text data to store and encrypt in this version of the secret"
  type        = string
}

variable "description" {}

variable "tags" {}

variable "kms_key_id" {
  description = "ID of KMS key to encrypt secret"
  type        = string
  default     = null
}

variable "environment" {}