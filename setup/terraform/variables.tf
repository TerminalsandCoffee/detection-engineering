variable "aws_region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "kali_ami" {
  description = "AMI ID for Kali Linux"
  type        = string
}

variable "windows_ami" {
  description = "AMI ID for Windows Server"
  type        = string
}

variable "ubuntu_ami" {
  description = "AMI ID for Ubuntu VM"
  type        = string
}



variable "key_name" {
  description = "Name of the existing Key Pair to use for SSH/RDP access"
  type        = string
}
