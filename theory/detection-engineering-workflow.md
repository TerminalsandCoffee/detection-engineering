# Detection Engineering Workflow

The detection engineering workflow is a repeatable, end-to-end process for creating, validating, deploying, and maintaining detection rules. Each phase feeds into the next, forming a continuous loop that improves detection coverage over time.

## Workflow Phases

| Phase | Input | Output |
|-------|-------|--------|
| 1. Requirements | Threat intel, incident reports, hunt findings | Prioritized detection gap |
| 2. Research | Threat reports, ATT&CK techniques, log sources | Detection hypothesis |
| 3. Development | Hypothesis, query language, Wazuh XML template | Draft detection rule |
| 4. Testing | Draft rule, sample data, lab environment | Validated detection rule |
| 5. Deployment | Validated rule, CI/CD pipeline | Production detection |
| 6. Tuning & Maintenance | Alert feedback, false positive data | Refined detection rule |

---

## 1. Requirements

Detection work starts with a question: **what do we need to detect, and why?**

Inputs come from across the security operations team:

- **Threat Intelligence** — new adversary TTPs, campaigns targeting your industry, or published indicators of compromise
- **Incident Response** — gaps identified during real incident investigations where existing detections failed to fire
- **Threat Hunting** — hypotheses that were manually validated and now need to be automated as persistent detections
- **Compliance / Risk** — regulatory requirements or risk assessments that mandate monitoring for specific activity

The output of this phase is a **prioritized detection gap** — a clear statement of what malicious behavior needs a detection and why it matters to the organization.

## 2. Research

With a detection gap identified, research the adversary behavior in depth:

- **Map to MITRE ATT&CK** — Identify the relevant tactic, technique, and sub-technique. This drives both the detection logic and the metadata in the Wazuh rule file.
- **Identify data sources** — Determine which logs or telemetry provide visibility into the behavior. Common sources include endpoint logs (Sysmon, EDR), network traffic, authentication logs, and cloud audit trails.
- **Wazuh Decoder Development** — If the log source is not natively parsed by Wazuh, develop a custom XML decoder (`/detections/decoders/`) to extract relevant fields before rule creation.
- **Study adversary tradecraft** — Review threat reports, malware samples, and red team tooling to understand how the technique is executed in practice. Look for observable artifacts like process command lines, file paths, registry keys, or network patterns.
- **Document assumptions** — Write down what conditions must be true for the detection to work (e.g., "Sysmon Process Create events are being collected from all endpoints").

The output is a **detection hypothesis**: a plain-language statement describing the observable behavior and the data source that captures it.

> **Example hypothesis**: "When an attacker uses msfvenom to generate a PowerShell payload, the default command line contains the string `powershell -w hidden -nop -c $a=`. This string appears in Sysmon Process Create events under `process.command_line`."

## 3. Development

Translate the hypothesis into a detection rule. In this repo, detections follow the **Wazuh XML** format:

```xml
<group name="windows, detection_engineering,">
  <rule id="100002" level="10">
    <if_sid>60009</if_sid> <!-- Base Sysmon Rule -->
    <field name="win.eventdata.image">powershell.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(-w hidden|-windowstyle hidden)</field>
    <description>PowerShell Execution with Hidden Window</description>
    <mitre>
      <id>T1059.001</id>
    </mitre>
  </rule>
</group>
```

### What Makes a Good Detection

- **Specific** — targets a well-defined behavior, not broad categories of activity
- **Mapped** — includes accurate MITRE ATT&CK tactic and technique references
- **Described** — the `description` field explains what the rule detects and why it matters, not just what query it runs
- **Scored** — `risk_score` and `severity` reflect the actual risk to the organization, considering both impact and confidence
- **Testable** — the query logic can be triggered in a lab to verify it works

### Detection as Code

Treating detections as code means they follow software engineering practices:

- **Version control** — all rules are stored in Git and changes are tracked through commits
- **Peer review** — new or modified detections go through pull requests before merging
- **Validation** — automated scripts check XML syntax and MITRE ATT&CK mappings
- **CI/CD** — GitHub Actions workflows can automate validation on every push (see `.github/workflows/`)

## 4. Testing

Before a detection reaches production, it must be tested:

- **Unit testing** — use the validation scripts in `development/` to confirm the rule has valid XML syntax, all required fields are present, and MITRE mappings are correct
- **Lab validation** — execute the adversary technique in a controlled environment and verify the detection fires. The `setup/` directory contains Terraform configurations for deploying a lab environment
- **False positive analysis** — run the query against production data (or a representative sample) to identify benign activity that would trigger the rule. Adjust the query logic or add exclusions as needed
- **Edge case review** — consider variations of the technique that might evade the detection (different tools, obfuscation, alternative execution methods)

A detection is ready for deployment when it:
1. Passes all automated validation checks
2. Successfully fires on simulated adversary behavior
3. Has an acceptable false positive rate

## 5. Deployment

Deploy the validated detection to the production SIEM or detection platform:

- Merge the detection rule into the `main` branch through a pull request
- CI/CD pipelines pick up the change and push the rule to the detection platform
- Verify the rule is active and receiving data in production
- Document the deployment in the detection's commit history

## 6. Tuning & Maintenance

Detection engineering is not a "set and forget" activity. Every deployed detection requires ongoing attention:

- **Monitor alert volume** — a sudden spike or drop in alerts may indicate a change in the environment or a problem with the detection
- **Track false positives** — when analysts flag alerts as false positives, update the detection logic to exclude the benign behavior
- **Reassess risk scores** — as the threat landscape changes, a detection's `risk_score` and `severity` may need adjustment
- **Update for ATT&CK changes** — the MITRE ATT&CK framework is updated regularly; keep technique and tactic mappings current
- **Retire stale detections** — if the underlying data source is no longer available or the technique is no longer relevant, remove the detection rather than leaving it broken

## The Feedback Loop

The workflow is a cycle, not a straight line. Each phase generates feedback that improves the others:

```
Requirements ──> Research ──> Development ──> Testing ──> Deployment
     ^                                                        │
     │                                                        v
     └──────────────────── Tuning & Maintenance ──────────────┘
```

- Incidents that bypass detections create new **requirements**
- False positives from production drive **research** into better query logic
- Retired detections reveal **gaps** that restart the cycle

This continuous loop is what separates a mature detection engineering program from a static set of vendor-provided rules.
