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

# --- IAM Role for SSM ---
resource "aws_iam_role" "ssm_role" {
  name = "detection-lab-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Detection Lab SSM Role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "detection-lab-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# --- Networking Stack ---
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Detection Lab VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "Detection Lab IGW"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "Detection Lab Public Subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Detection Lab Public RT"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "lab_sg" {
  name        = "detection-lab-sg"
  description = "Allow inbound traffic for Detection Lab"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WinRM"
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Elasticsearch"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kibana"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Detection Lab SG"
  }
}

# Kali Linux Instance
resource "aws_instance" "kali_linux" {
  ami                    = var.kali_ami
  instance_type          = "t3.medium" # Changed to t3 for UEFI support
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > /var/log/user-data.log 2>&1

              echo "=== Installing SSM Agent on Kali ==="

              # Wait for network
              sleep 10

              # Create temp directory
              cd /tmp

              # Download SSM agent for Debian-based systems
              wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb

              # Install SSM agent
              dpkg -i amazon-ssm-agent.deb

              # Enable and start SSM agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent

              echo "=== SSM Agent Installation Complete ==="
              EOF

  tags = {
    Name        = "Kali Linux"
    Environment = "Detection Engineering Lab"
  }
}

# Windows Server Instance
resource "aws_instance" "windows_server" {
  ami                    = var.windows_ami
  instance_type          = "t3.medium" # Windows requires at least 4GB RAM. t3 supports UEFI.
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = var.key_name

  # Wait for Elastic instance to exist (it will be referenced in user_data)
  depends_on = [aws_instance.ubuntu_vm]

  user_data = <<-EOF
              <powershell>
              Start-Transcript -Path "C:\user-data-log.txt" -Append

              Write-Host "=== Starting Windows Sensor Setup ==="
              
              # Create working directory
              New-Item -ItemType Directory -Path "C:\DetectionLab" -Force
              Set-Location "C:\DetectionLab"
              
              # --- Install Sysmon ---
              Write-Host "Installing Sysmon..."
              
              # Download Sysmon
              Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
              Expand-Archive -Path "Sysmon.zip" -DestinationPath ".\Sysmon" -Force
              
              # Download SwiftOnSecurity Sysmon config (industry standard)
              Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig.xml"
              
              # Install Sysmon with config
              .\Sysmon\Sysmon64.exe -accepteula -i sysmonconfig.xml
              
              Write-Host "Sysmon installed!"
              
              # --- Install Winlogbeat ---
              Write-Host "Installing Winlogbeat..."
              
              $elasticHost = "${aws_instance.ubuntu_vm.private_ip}:9200"
              $kibanaHost = "${aws_instance.ubuntu_vm.private_ip}:5601"
              
              # Download Winlogbeat
              Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.17.0-windows-x86_64.zip" -OutFile "winlogbeat.zip"
              Expand-Archive -Path "winlogbeat.zip" -DestinationPath "C:\Program Files" -Force
              Rename-Item "C:\Program Files\winlogbeat-8.17.0-windows-x86_64" "C:\Program Files\Winlogbeat" -Force
              
              # Configure Winlogbeat
              $winlogbeatConfig = @"
              winlogbeat.event_logs:
                - name: Application
                  ignore_older: 72h
                - name: System
                  ignore_older: 72h
                - name: Security
                  ignore_older: 72h
                - name: Microsoft-Windows-Sysmon/Operational
                - name: Microsoft-Windows-PowerShell/Operational
                - name: Windows PowerShell
                - name: Microsoft-Windows-WMI-Activity/Operational

              output.elasticsearch:
                hosts: ["http://$elasticHost"]
              
              setup.kibana:
                host: "http://$kibanaHost"
              
              setup.ilm.enabled: false
              setup.template.enabled: true
              setup.template.name: "winlogbeat"
              setup.template.pattern: "winlogbeat-*"
              
              logging.level: info
              logging.to_files: true
              logging.files:
                path: C:\Program Files\Winlogbeat\logs
                name: winlogbeat
                keepfiles: 3
              "@
              
              $winlogbeatConfig | Out-File -FilePath "C:\Program Files\Winlogbeat\winlogbeat.yml" -Encoding UTF8
              
              # Install Winlogbeat service
              Set-Location "C:\Program Files\Winlogbeat"
              PowerShell.exe -ExecutionPolicy Bypass -File .\install-service-winlogbeat.ps1
              
              # Wait a bit for Elasticsearch to be ready, then start
              Write-Host "Waiting 120 seconds for Elasticsearch to be ready..."
              Start-Sleep -Seconds 120
              
              # Start Winlogbeat service
              Start-Service winlogbeat
              
              Write-Host "=== Windows Sensor Setup Complete ==="
              Write-Host "Sysmon + Winlogbeat installed and shipping to $elasticHost"
              
              Stop-Transcript
              </powershell>
              EOF

  tags = {
    Name        = "Windows Server"
    Environment = "Detection Engineering Lab"
  }
}

# Ubuntu VM Instance (Elastic Stack)
resource "aws_instance" "ubuntu_vm" {
  ami                    = var.ubuntu_ami
  instance_type          = "t3.large" # Changed to t3 for UEFI support. Elasticsearch needs at least 4GB RAM
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > /var/log/user-data.log 2>&1

              echo "=== Starting Elastic Stack Installation ==="
              
              # Wait for system to be ready
              sleep 30
              
              # Update system
              apt-get update && apt-get upgrade -y
              
              # Install dependencies
              apt-get install -y apt-transport-https curl gnupg
              
              # Add Elastic GPG key and repo
              curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic.gpg
              echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
              
              apt-get update
              
              # Install Elasticsearch
              apt-get install -y elasticsearch
              
              # Configure Elasticsearch for lab use (disable security for simplicity)
              cat > /etc/elasticsearch/elasticsearch.yml <<ESCONFIG
              cluster.name: detection-lab
              node.name: elastic-node
              path.data: /var/lib/elasticsearch
              path.logs: /var/log/elasticsearch
              network.host: 0.0.0.0
              http.port: 9200
              discovery.type: single-node
              xpack.security.enabled: false
              xpack.security.enrollment.enabled: false
              ESCONFIG
              
              # Start Elasticsearch
              systemctl daemon-reload
              systemctl enable elasticsearch
              systemctl start elasticsearch
              
              # Wait for Elasticsearch to be ready
              echo "Waiting for Elasticsearch..."
              until curl -s http://localhost:9200 > /dev/null; do
                sleep 5
              done
              echo "Elasticsearch is up!"
              
              # Install Kibana
              apt-get install -y kibana
              
              # Configure Kibana
              cat > /etc/kibana/kibana.yml <<KBCONFIG
              server.port: 5601
              server.host: "0.0.0.0"
              server.name: "detection-lab-kibana"
              elasticsearch.hosts: ["http://localhost:9200"]
              KBCONFIG
              
              # Start Kibana
              systemctl daemon-reload
              systemctl enable kibana
              systemctl start kibana
              
              echo "=== Elastic Stack Installation Complete ==="
              echo "Kibana will be available at http://<public-ip>:5601 in a few minutes"
              EOF

  tags = {
    Name        = "Elastic Stack"
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

output "kibana_url" {
  value = "http://${aws_instance.ubuntu_vm.public_ip}:5601"
}

output "elasticsearch_url" {
  value = "http://${aws_instance.ubuntu_vm.public_ip}:9200"
}
