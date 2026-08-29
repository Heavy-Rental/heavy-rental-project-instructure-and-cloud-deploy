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
  description = "REST SoR database name on the primary RDS instance."
}

variable "db_haystack_name" {
  type        = string
  default     = "haystack"
  description = "Haystack database name on the second RDS instance."
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

variable "deployment" {
  type        = string
  default     = "academy"
  description = "academy = Vocareum LabRole. actual = public AWS (Environment AWS_ACTUAL). S3 suffix is lowercase."

  validation {
    condition     = contains(["academy", "actual"], var.deployment)
    error_message = "deployment must be academy or actual."
  }
}

variable "lab_role_name" {
  type        = string
  default     = "LabRole"
  description = "Pre-created Vocareum IAM role. LabInstanceProfile must use this role. Do not create IAM."
}

variable "alarm_email" {
  type        = string
  default     = ""
  description = "Optional SNS email for CloudWatch alarms. Empty = topic only, no subscription. From Environment ALARM_EMAIL."
}

variable "bastion_ssh_cidrs" {
  type        = list(string)
  default     = []
  description = "IPv4 CIDRs allowed to SSH to hr-bastion. Empty = SSM onto the bastion, then SSH to guests. Never 0.0.0.0/0. From Environment BASTION_SSH_CIDRS."

  validation {
    condition = alltrue([
      for c in var.bastion_ssh_cidrs :
      can(cidrhost(c, 0)) && !contains(["0.0.0.0/0", "::/0"], c)
    ])
    error_message = "bastion_ssh_cidrs must be IPv4 CIDR blocks and must not include 0.0.0.0/0."
  }
}
