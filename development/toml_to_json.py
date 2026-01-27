"""
Upload TOML detection rules to Elastic Security.

Usage:
    python toml_to_json.py [--dry-run] [--detections-dir PATH]

Environment Variables:
    ELASTIC_KEY: API key for Elastic Security
    ELASTIC_URL: (optional) Elastic Security API URL
"""
import argparse
import json
import os
import sys
import tomllib
from pathlib import Path

import requests


REQUIRED_FIELDS_BY_TYPE = {
    "query": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "threat"],
    "eql": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "language", "threat"],
    "threshold": ["author", "description", "name", "rule_id", "risk_score", "severity", "type", "query", "threshold", "threat"],
}

DEFAULT_URL = "https://detectionengineering101.kb.us-central1.gcp.cloud.es.io:9243/api/detection_engine/rules"


def load_detection(file_path: Path) -> dict:
    """Load and parse a TOML detection file."""
    with open(file_path, "rb") as f:
        return tomllib.load(f)


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


def upload_detection(url: str, headers: dict, payload: dict) -> dict:
    """Upload a detection rule to Elastic Security."""
    response = requests.post(url, headers=headers, json=payload)
    response.raise_for_status()
    return response.json()


def main():
    parser = argparse.ArgumentParser(description="Upload TOML detections to Elastic Security")
    parser.add_argument("--dry-run", action="store_true", help="Print payloads without uploading")
    parser.add_argument("--detections-dir", default="detections", help="Path to detections directory")
    args = parser.parse_args()

    detections_path = Path(args.detections_dir)
    if not detections_path.exists():
        print(f"Error: Detections directory not found: {detections_path}", file=sys.stderr)
        sys.exit(1)

    if not args.dry_run:
        api_key = os.environ.get("ELASTIC_KEY")
        if not api_key:
            print("Error: ELASTIC_KEY environment variable not set", file=sys.stderr)
            sys.exit(1)

        url = os.environ.get("ELASTIC_URL", DEFAULT_URL)
        headers = {
            "Content-Type": "application/json;charset=UTF-8",
            "kbn-xsrf": "true",
            "Authorization": f"ApiKey {api_key}",
        }

    for toml_file in detections_path.glob("**/*.toml"):
        print(f"Processing: {toml_file}")

        try:
            alert = load_detection(toml_file)
            payload = build_payload(alert)

            if payload is None:
                rule_type = alert.get("rule", {}).get("type", "unknown")
                print(f"  Skipped: Unsupported rule type '{rule_type}'")
                continue

            if args.dry_run:
                print(f"  Payload: {json.dumps(payload, indent=2)}")
            else:
                result = upload_detection(url, headers, payload)
                print(f"  Uploaded: {result.get('name', 'unknown')} ({result.get('id', 'no-id')})")

        except requests.RequestException as e:
            print(f"  Error uploading: {e}", file=sys.stderr)
        except Exception as e:
            print(f"  Error processing: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
