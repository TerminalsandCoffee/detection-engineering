# Security Operations

Security Operations (SecOps) is the practice of continuously monitoring, detecting, and responding to threats across an organization's environment. It brings together several specialized functions that work as a coordinated unit.

## Core Functions

### Threat Intelligence

- Collects and processes **Indicators of Compromise** (IoCs) — file hashes, IP addresses, domains, and URLs associated with known threats
- Tracks adversary groups, campaigns, and evolving tactics, techniques, and procedures (TTPs)
- Produces finished intelligence reports that inform detection engineering, threat hunting, and incident response priorities

### Incident Response

- Responds to vendor-based and custom security alerts
- Investigates, contains, and remediates confirmed security incidents
- Provides feedback to other teams — identifying detection gaps, missing log sources, and areas where tooling failed during an incident
- Documents lessons learned that feed back into the detection engineering cycle

### Threat Hunting

- Proactively searches for malicious activity that is already present in the environment but has not triggered an alert
- Finds visibility or tooling gaps — log sources that are missing, telemetry that is not being collected, or blind spots in detection coverage
- Develops hypotheses based on threat intelligence and validates them against real data
- Hands off confirmed findings to detection engineering for automation as persistent rules

### Detection Engineering

- Creates custom alerts for the Incident Response team tailored to the organization's environment and threat landscape
- Develops unit tests to confirm working detections and capabilities
- Maintains detection rules as code — version controlled, peer reviewed, and validated through CI/CD
- Maps all detections to the MITRE ATT&CK framework for coverage tracking

## Where Does Detection Engineering Fit In?

Detection engineering sits at the center of the security operations cycle. It consumes input from every other function and produces output that each function depends on:

<img width="420" height="368" alt="image" src="https://github.com/user-attachments/assets/4bc5840c-2227-4b2b-a6d9-656cc45355fb" />


```
                ┌─────────────────────┐
                │ Threat Intelligence │
                │(TTPs, IoCs, reports)│
                └────────┬────────────┘
                         │ informs
                         v
┌──────────────┐   ┌─────────────────────┐   ┌────────────────┐
│ Threat       │──>│ Detection           │──>│ Incident       │
│ Hunting      │   │ Engineering         │   │ Response       │
│ (hypotheses, │   │ (rules, tests,      │   │ (alerts,       │
│  gaps)       │   │  coverage)          │   │  investigations)│
└──────────────┘   └─────────────────────┘   └───────┬────────┘
                         ^                           │
                         │      feedback             │
                         └───────────────────────────┘
```

| Source | What It Provides | What Detection Engineering Produces |
|--------|-----------------|-------------------------------------|
| Threat Intelligence | New TTPs, campaign details, IoCs | Detection rules targeting reported adversary behavior |
| Incident Response | Gaps found during investigations, false positive reports | Tuned rules, new detections for missed activity |
| Threat Hunting | Validated hypotheses, visibility gaps | Automated detections from manual hunt findings |

Without detection engineering, threat intelligence stays theoretical, hunt findings remain one-time efforts, and incident response operates reactively without custom alerting.

## How Does Detection Engineering Work?

At a high level, detection engineering follows a six-phase workflow:

1. **Requirements** — identify what needs to be detected based on intel, incidents, or hunts
2. **Research** — map the behavior to MITRE ATT&CK, identify data sources, and form a detection hypothesis
3. **Development** — write the detection rule in the standardized TOML format used by this repo
4. **Testing** — validate the rule fires correctly in a lab and produces an acceptable false positive rate
5. **Deployment** — merge the rule through a pull request and push it to the detection platform via CI/CD
6. **Tuning & Maintenance** — monitor alert volume, refine queries, and retire stale detections

For a detailed breakdown of each phase, see [Detection Engineering Workflow](detection-engineering-workflow.md).
