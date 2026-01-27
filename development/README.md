# Development Scripts

Python utilities for managing detection rules lifecycle.

## Scripts

| Script | Purpose |
|--------|---------|
| `validation.py` | Validates TOML syntax and required fields |
| `mitre.py` | Validates MITRE ATT&CK technique/tactic mappings |
| `toml_to_json.py` | Uploads detections to Elastic Security API |
| `update_alert.py` | Updates existing rules (used in CI/CD) |
| `toml_to_csv.py` | Exports detections to CSV for reporting |
| `toml_to_md.py` | Generates markdown documentation |
| `toml_to_navigator.py` | Creates ATT&CK Navigator layer JSON |
| `toml_to_report.py` | Generates detection coverage reports |

## Usage

```bash
# Validate all detections
python validation.py

# Validate MITRE mappings
python mitre.py

# Upload to Elastic (requires ELASTIC_KEY env var)
python toml_to_json.py --dry-run  # Preview
python toml_to_json.py            # Upload

# Generate reports
python toml_to_csv.py
python toml_to_navigator.py
```

## Environment Variables

- `ELASTIC_KEY`: API key for Elastic Security
- `ELASTIC_URL`: (optional) Override default Elastic endpoint
- `CHANGED_FILES`: Used by `update_alert.py` in CI/CD pipelines
