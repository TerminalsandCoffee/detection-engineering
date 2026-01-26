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
  instance_type          = "t2.large" # Elasticsearch needs at least 4GB RAM
  vpc_security_group_ids = [var.security_group_id]
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
