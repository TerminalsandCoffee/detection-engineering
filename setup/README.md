# Setup

Infrastructure and environment setup for the detection engineering lab.

## Contents

- `terraform/` - IaC for deploying the lab environment on AWS

## Lab Architecture

The Terraform configuration deploys:

| Instance | Purpose | Type |
|----------|---------|------|
| **Elastic Stack** | Elasticsearch + Kibana for log ingestion and SIEM | Ubuntu, t2.large |
| **Windows Server** | Target host with Sysmon + Winlogbeat | Windows, t2.medium |
| **Kali Linux** | Attack simulation and testing | Kali, t2.medium |

## Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Requirements

- AWS credentials configured
- Variables set in `terraform.tfvars` or via `-var` flags:
  - `aws_region`
  - `kali_ami`
  - `windows_ami`
  - `ubuntu_ami`
  - `security_group_id`
  - `key_name`
