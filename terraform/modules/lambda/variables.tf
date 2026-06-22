variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "version" {
  description = "Version label for blue/green deployment"
  type        = string
  default     = "Blue"
}

variable "enable_blue_green" {
  description = "Enable blue/green Lambda aliases"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
