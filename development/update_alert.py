"""
Update changed TOML detection rules in Elastic Security.

This script is designed to run in CI/CD when detection files change.
It attempts to PUT (update) first, and falls back to POST (create) if the rule doesn't exist.

Environment Variables:
    ELASTIC_KEY: API key for Elastic Security
    CHANGED_FILES: Space or comma-separated list of changed filenames
"""
import os
import sys
import tomllib

import requests


BASE_URL = "https://detectionengineering101.kb.us-central1.gcp.cloud.es.io:9243/api/detection_engine/rules"

REQUIRED_FIELDS_BY_TYPE = {
    "query": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "threat"],
    "eql": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "language", "threat"],
    "threshold": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "threshold", "threat"],
}


def build_payload(alert: dict) -> dict | None:
    """Build the JSON payload for Elastic Security API."""
    rule = alert.get("rule", {})
    rule_type = rule.get("type")

    if rule_type not in REQUIRED_FIELDS_BY_TYPE:
        return None

    required_fields = REQUIRED_FIELDS_BY_TYPE[rule_type]
    payload = {field: rule[field] for field in required_fields if field in rule}
    payload["enabled"] = True

    return payload


def main():
    api_key = os.environ.get("ELASTIC_KEY")
    if not api_key:
        print("Error: ELASTIC_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    changed_files = os.environ.get("CHANGED_FILES", "")
    if not changed_files:
        print("No changed files specified")
        sys.exit(0)

    headers = {
        "Content-Type": "application/json;charset=UTF-8",
        "kbn-xsrf": "true",
        "Authorization": f"ApiKey {api_key}",
    }

    for root, dirs, files in os.walk("detections/"):
        for filename in files:
            if filename not in changed_files:
                continue
            if not filename.endswith(".toml"):
                continue

            full_path = os.path.join(root, filename)
            print(f"Processing: {full_path}")

            with open(full_path, "rb") as f:
                alert = tomllib.load(f)

            payload = build_payload(alert)
            if payload is None:
                rule_type = alert.get("rule", {}).get("type", "unknown")
                print(f"  Skipped: Unsupported rule type '{rule_type}'")
                continue

            rule_id = alert["rule"]["rule_id"]
            url = f"{BASE_URL}?rule_id={rule_id}"

            # Try to update first (PUT), create if not found (POST)
            response = requests.put(url, headers=headers, json=payload)
            result = response.json()

            if result.get("status_code") == 404:
                response = requests.post(BASE_URL, headers=headers, json=payload)
                result = response.json()
                print(f"  Created: {result.get('name', filename)}")
            else:
                print(f"  Updated: {result.get('name', filename)}")


if __name__ == "__main__":
    main()

