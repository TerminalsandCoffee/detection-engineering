terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Kali Linux Instance
resource "aws_instance" "kali_linux" {
  ami                    = var.kali_ami
  instance_type          = "t2.medium" # Recommended for GUI usage, adjust as needed (t2.micro is free tier eligible but slow for Kali GUI)
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  tags = {
    Name        = "Kali Linux"
    Environment = "Detection Engineering Lab"
  }
}

# Windows Server Instance
resource "aws_instance" "windows_server" {
  ami                    = var.windows_ami
  instance_type          = "t2.medium" # Windows requires at least t2.medium or t3.medium for decent performance
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  tags = {
    Name        = "Windows Server"
    Environment = "Detection Engineering Lab"
  }
}

# Ubuntu VM Instance
resource "aws_instance" "ubuntu_vm" {
  ami                    = var.ubuntu_ami
  instance_type          = "t2.micro" # t2.micro is usually sufficient for headless Ubuntu
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  tags = {
    Name        = "Ubuntu VM"
    Environment = "Detection Engineering Lab"
  }
}

output "kali_public_ip" {
  value = aws_instance.kali_linux.public_ip
}

output "windows_public_ip" {
  value = aws_instance.windows_server.public_ip
}

output "ubuntu_public_ip" {
  value = aws_instance.ubuntu_vm.public_ip
}
