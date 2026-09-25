variable "app_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "db_address" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_name" {
  type = string
}

variable "bucket_id" {
  type = string
}

variable "app_image" {
  type    = string
  default = "ruslanhlukhov/node-form-app:v16"
}