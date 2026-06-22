terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key = "prod.tfstate"
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

# Blue Lambda (stable/current)
module "lambda_blue" {
  source            = "../../modules/lambda"
  function_name     = "${var.environment_name}-hello-function-blue"
  environment       = var.environment_name
  version           = "Blue"
  enable_blue_green = false
  tags              = merge(local.common_tags, { Slot = "blue" })
}

# Green Lambda (new deployment target)
module "lambda_green" {
  source            = "../../modules/lambda"
  function_name     = "${var.environment_name}-hello-function-green"
  environment       = var.environment_name
  version           = "Green"
  enable_blue_green = false
  tags              = merge(local.common_tags, { Slot = "green" })
}

# API Gateway points to active slot (controlled by var.active_slot)
module "api_gateway" {
  source               = "../../modules/api-gateway"
  api_name             = "${var.environment_name}-hello-api"
  environment          = var.environment_name
  stage_name           = "prod"
  lambda_invoke_arn    = var.active_slot == "blue" ? module.lambda_blue.invoke_arn : module.lambda_green.invoke_arn
  lambda_function_name = var.active_slot == "blue" ? module.lambda_blue.function_name : module.lambda_green.function_name
  use_api_key          = true
  tags                 = local.common_tags
}
