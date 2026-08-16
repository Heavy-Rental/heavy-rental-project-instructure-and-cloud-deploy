variable "db_master_password" {
  type        = string
  sensitive   = true
  description = "RDS master password from GitHub Environment SPRING_DATASOURCE_PASSWORD. Never put this on the Run form."

  validation {
    condition     = length(var.db_master_password) >= 8
    error_message = "RDS master password must be at least 8 characters."
  }
}

variable "db_master_username" {
  type        = string
  default     = "hradmin"
  description = "RDS master username (not the Vocareum AWS user)."
}

variable "db_name" {
  type        = string
  default     = "heavy_rental"
  description = "Initial REST SoR database name."
}

# Workflow uses this for plan when SPRING_DATASOURCE_PASSWORD is unset.
# action=apply MUST refuse this value.
variable "db_password_plan_placeholder" {
  type        = string
  default     = "PlanOnlyNotApplied1!"
  description = "Sentinel. Apply fails if db_master_password equals this."
}

variable "lab_instance_profile_name" {
  type        = string
  default     = "LabInstanceProfile"
  description = "Pre-created Vocareum instance profile. Must contain LabRole. Do not create IAM."
}

variable "lab_role_name" {
  type        = string
  default     = "LabRole"
  description = "Pre-created Vocareum IAM role. LabInstanceProfile must use this role. Do not create IAM."
}
