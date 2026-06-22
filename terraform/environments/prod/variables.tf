variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "active_slot" {
  description = "Active deployment slot for blue/green (blue or green)"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_slot)
    error_message = "active_slot must be 'blue' or 'green'."
  }
}
