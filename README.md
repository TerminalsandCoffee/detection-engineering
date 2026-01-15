# Detection Engineering Fundamentals

A comprehensive repository for creating, managing, and validating security detection rules in TOML format, mapped to the MITRE ATT&CK framework.

## Overview

This repository contains custom security detection rules designed to identify malicious activity across enterprise environments. Each detection is structured in TOML format and includes metadata, query logic, risk scoring, and MITRE ATT&CK framework mappings.

Detection Engineering is a critical component of Security Operations that:
- Creates custom alerts for Incident Response teams
- Develops unit tests to confirm working detections & capabilities
- Bridges the gap between threat intelligence and actionable security monitoring

## Repository Structure

```
detection-engineering/
├── detections/          # TOML-formatted detection rules
├── development/         # Python scripts for validation and conversion
├── metrics/             # Generated metrics, reports, and visualizations
├── theory/             # Documentation on detection engineering concepts
└── .github/workflows/   # GitHub Actions workflows (currently disabled)
```

## Detection Format

Each detection rule is stored as a TOML file with the following structure:

```toml
[metadata]
creation_date = "YYYY/MM/DD"

[rule]
author = ["Author Name"]
description = "Detection description"
name = "Detection Name"
risk_score = 50
severity = "medium"
type = "query"
rule_id = "unique-uuid"
query = "your detection query here"

[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1059"
name = "Command and Scripting Interpreter"
reference = "https://attack.mitre.org/techniques/T1059/"

[rule.threat.tactic]
id = "TA0002"
name = "Execution"
reference = "https://attack.mitre.org/tactics/TA0002/"
```

## Theory & Documentation

Explore detection engineering concepts in the `theory/` directory:

- **[Security Operations](theory/security-operations.md)**: Overview of SecOps functions
- **[Detection Engineering Workflow](theory/detection-engineering-workflow.md)**: Workflow documentation
- **[Frameworks](theory/frameworks.md)**: Security frameworks (MITRE ATT&CK, Cyber Kill Chain, F3EAD)


### Detection Requirements

- Valid TOML syntax
- All required fields present
- Valid MITRE ATT&CK technique/tactic mappings
- Unique `rule_id` (UUID format)
- Descriptive `name` and `description`
- Appropriate `risk_score` and `severity`

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Resources

- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Elastic Security Detection Rules](https://www.elastic.co/guide/en/security/current/detection-engine-overview.html)
- [Detection Engineering Best Practices](https://github.com/DetectionEngineering)




