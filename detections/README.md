# Detections

TOML-formatted detection rules for Elastic Security, mapped to the MITRE ATT&CK framework.

## Structure

Each detection file contains:
- **metadata**: Creation date and versioning info
- **rule**: Detection logic including query, severity, and MITRE mappings

## Current Detections

| Detection | Severity | MITRE Tactic |
|-----------|----------|--------------|
| BAT files over HTTP on unusual port | Medium | Execution |
| Data archive for exfiltration | High | Collection |
| Data exfiltration over FTP | High | Exfiltration |
| Excessive web traffic | Medium | Command and Control |
| Msfvenom PowerShell payload | High | Execution |
| PowerShell exec via BAT | High | Execution |
| PowerShell downloading BAT files | High | Execution |
| Suspicious file added to registry | High | Persistence |
| Suspicious file written to temp | High | Discovery |
| Web scanner activity (Nmap/Nikto) | Medium | Reconnaissance |

## Adding New Detections

1. Create a new `.toml` file following the template in the root README
2. Ensure valid MITRE ATT&CK mappings
3. Run `python development/validation.py` to validate
4. Run `python development/mitre.py` to verify MITRE mappings
