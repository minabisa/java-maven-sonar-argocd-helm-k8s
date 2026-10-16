variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "jenkins-docker"
}
variable "instance_type" {
  type    = string
  default = "t2.large"
}
variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
}
variable "allowed_cidr" {
  type        = string
  description = "Your public IP in CIDR notation, e.g. 203.0.113.10/32"
}

variable "data_volume_size" {
  description = "Size of the additional EBS volume in GiB"
  type        = number
  default     = 20
}
variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 30
}
