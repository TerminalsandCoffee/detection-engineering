# Frameworks

Security frameworks provide structured models for understanding adversary behavior and organizing defensive operations. The three frameworks below are commonly used in detection engineering to prioritize coverage, map detections to real-world threats, and drive intelligence-led operations.

## The Cyber Kill Chain

Developed by Lockheed Martin, the **Cyber Kill Chain** models the stages an adversary moves through during an intrusion. Defenders can use it to identify where detections exist and where gaps remain.

| Stage | Description | Detection Opportunity |
|-------|-------------|----------------------|
| **Reconnaissance** | Adversary researches the target — scanning, OSINT, identifying attack surface | Web scanner activity, unusual DNS lookups, port scans |
| **Weaponization** | Adversary builds a deliverable payload (e.g., malicious document, exploit kit) | Typically not observable by the target organization |
| **Delivery** | Payload is transmitted to the target — phishing email, drive-by download, USB | Email gateway alerts, web proxy logs, endpoint file creation events |
| **Exploitation** | Payload executes and exploits a vulnerability | Process creation anomalies, script execution, application crashes |
| **Installation** | Adversary establishes persistence — registry keys, scheduled tasks, services | File writes to startup locations, registry modifications, new services |
| **Command & Control** | Compromised system communicates with adversary infrastructure | Unusual outbound connections, beaconing patterns, DNS tunneling |
| **Actions on Objectives** | Adversary achieves their goal — data exfiltration, destruction, lateral movement | Large data transfers, archive creation, access to sensitive systems |

### Applying the Kill Chain to Detection Engineering

- **Map existing detections** to kill chain stages to visualize where coverage is strong and where it is thin
- **Prioritize development** toward stages with the fewest detections — a common gap is between Delivery and Exploitation
- **Layer detections** across multiple stages so that if an adversary evades one, a later stage catches them

> The kill chain's linear model is a useful starting point, but real intrusions are not always sequential. Adversaries may skip stages, repeat them, or operate across multiple chains simultaneously.

## MITRE ATT&CK

The **MITRE ATT&CK** (Adversarial Tactics, Techniques, and Common Knowledge) framework is the industry standard for categorizing adversary behavior. It is more granular than the kill chain, organizing behaviors into **tactics** (the "why") and **techniques** (the "how").

### Structure

| Level | Description | Example |
|-------|-------------|---------|
| **Tactic** | The adversary's objective at a given stage | Execution (TA0002) |
| **Technique** | The method used to achieve the objective | Command and Scripting Interpreter (T1059) |
| **Sub-technique** | A specific variation of the technique | PowerShell (T1059.001) |
| **Procedure** | A real-world implementation by a specific adversary group | APT29 using encoded PowerShell commands |

### How This Repo Uses ATT&CK

Every detection rule in the `detections/` directory includes ATT&CK mappings in the TOML metadata:

```toml
[[rule.threat]]
framework = "MITRE ATT&CK"
[[rule.threat.technique]]
id = "T1059"
name = "Command and Scripting Interpreter"
reference = "https://attack.mitre.org/techniques/T1059/"
[[rule.threat.technique.subtechnique]]
id = "T1059.001"
name = "PowerShell"
reference = "https://attack.mitre.org/techniques/T1059/001/"

[rule.threat.tactic]
id = "TA0002"
name = "Execution"
reference = "https://attack.mitre.org/tactics/TA0002/"
```

This mapping enables:

- **Coverage tracking** — identify which ATT&CK techniques have detections and which do not
- **Gap analysis** — prioritize detection development toward uncovered techniques relevant to your threat landscape
- **Reporting** — communicate detection maturity to stakeholders using a shared vocabulary
- **Validation** — automated scripts in `development/` verify that every detection has valid ATT&CK technique and tactic references

### ATT&CK Matrices

ATT&CK provides separate matrices for different platforms:

- **Enterprise** — Windows, macOS, Linux, Cloud (AWS, Azure, GCP), Network, Containers
- **Mobile** — Android, iOS
- **ICS** — Industrial Control Systems

Most detections in this repo target the Enterprise matrix, specifically Windows endpoint telemetry.

## F3EAD

**F3EAD** (Find, Fix, Finish, Exploit, Analyze, Disseminate) is an intelligence-driven operations cycle originally developed for military targeting. In security operations, it provides a framework for turning threat intelligence into detections and back into refined intelligence.

| Phase | Military Origin | Security Operations Application |
|-------|----------------|-------------------------------|
| **Find** | Identify the target | Identify adversary TTPs through threat intelligence or hunting |
| **Fix** | Locate the target | Determine which data sources and log events reveal the behavior |
| **Finish** | Engage the target | Build and deploy detection rules that alert on the behavior |
| **Exploit** | Gather intelligence from the engagement | Collect artifacts and context from triggered alerts and investigations |
| **Analyze** | Process gathered intelligence | Analyze incidents to understand adversary intent, tools, and infrastructure |
| **Disseminate** | Share findings | Feed findings back to threat intelligence and detection engineering teams |

### F3EAD in Practice

The F3EAD cycle connects directly to the detection engineering workflow:

1. **Find** — Threat intelligence identifies a new adversary technique targeting your industry
2. **Fix** — Research determines the technique generates Sysmon Process Create events with a distinctive command-line pattern
3. **Finish** — A detection rule is written, tested, and deployed to the production SIEM
4. **Exploit** — The detection fires on a real intrusion attempt, capturing the adversary's command-line arguments, source IP, and target systems
5. **Analyze** — Incident response investigates and discovers additional adversary infrastructure and TTPs not previously known
6. **Disseminate** — New intelligence is shared with the team, restarting the cycle with updated requirements

F3EAD is particularly useful for teams that want a tighter integration between threat intelligence and detection engineering, ensuring that intelligence outputs are always actionable and that detection outputs feed back into intelligence.

## Choosing a Framework

These frameworks are complementary, not competing:

| Framework | Best For | Granularity |
|-----------|----------|-------------|
| Cyber Kill Chain | Visualizing detection coverage across intrusion stages | High-level (7 stages) |
| MITRE ATT&CK | Mapping detections to specific adversary behaviors | Granular (hundreds of techniques) |
| F3EAD | Driving intelligence-led detection operations | Process-oriented (6 phases) |

A mature detection engineering program uses all three: the **kill chain** for strategic coverage planning, **ATT&CK** for tactical detection mapping, and **F3EAD** for operational workflow between intelligence and engineering teams.
