terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key = "staging.tfstate"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = var.environment_name
    Project     = "serverless-pipeline"
    Owner       = "lakshmi-priya"
    ManagedBy   = "Terraform"
  }
}

module "lambda" {
  source        = "../../modules/lambda"
  function_name = "${var.environment_name}-hello-function"
  environment   = var.environment_name
  version       = "Blue"
  tags          = local.common_tags
}

module "api_gateway" {
  source               = "../../modules/api-gateway"
  api_name             = "${var.environment_name}-hello-api"
  environment          = var.environment_name
  stage_name           = var.environment_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  use_api_key          = false
  tags                 = local.common_tags
}
