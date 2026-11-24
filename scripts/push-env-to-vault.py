#!/usr/bin/env python3
"""
Migrate local .env file keys into HashiCorp Vault KV v2 engine in memory.
Does not log secrets to stdout.
"""

import os
import sys
import argparse
from pathlib import Path

try:
    import hvac
except ImportError:
    print("Error: 'hvac' package not found. Please install via: pip install hvac")
    sys.exit(1)


def parse_env_file(file_path: Path) -> dict:
    if not file_path.exists():
        print(f"Error: .env file not found at: {file_path}")
        sys.exit(1)

    secrets = {}
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip("'\"")
                if key:
                    secrets[key] = val
    return secrets


def push_to_vault(vault_url: str, token: str, secret_path: str, secrets: dict, mount_point: str = "kv"):
    print(f"Connecting to Vault at: {vault_url}")
    client = hvac.Client(url=vault_url, token=token)

    if not client.is_authenticated():
        print("Error: Authentication to Vault failed. Please check your VAULT_TOKEN.")
        sys.exit(1)

    print(f"Pushing {len(secrets)} secrets to Vault mount '{mount_point}', path '{secret_path}'...")
    client.secrets.kv.v2.create_or_update_secret(
        path=secret_path,
        secret=secrets,
        mount_point=mount_point,
    )
    print("SUCCESS: Secrets written to Vault!")
    print("\nKeys stored:")
    for k in sorted(secrets.keys()):
        print(f"  - {k} [OK]")
    print("\nYou can now safely remove or archive your local .env file.")


def main():
    parser = argparse.ArgumentParser(description="Push local .env file into HashiCorp Vault")
    parser.add_argument("--env-file", default="d:/canned/heidelAI-Backend-main/.env", help="Path to .env file")
    parser.add_argument("--vault-url", default=os.getenv("VAULT_ADDR", "http://127.0.0.1:8200"), help="Vault URL")
    parser.add_argument("--vault-token", default=os.getenv("VAULT_TOKEN"), help="Vault Token (or reads ~/.vault-token)")
    parser.add_argument("--path", default="dev/heidelai-backend", help="KV secret path (default: dev/heidelai-backend)")
    parser.add_argument("--mount", default="kv", help="KV mount point (default: kv)")

    args = parser.parse_args()

    token = args.vault_token
    if not token:
        # Check ~/.vault-token
        home_token_path = Path.home() / ".vault-token"
        if home_token_path.exists():
            token = home_token_path.read_text(encoding="utf-8").strip()

    if not token:
        # Check .vault-credentials.json if in vault directory
        creds_json = Path("d:/canned/vault/.vault-credentials.json")
        if creds_json.exists():
            import json
            data = json.loads(creds_json.read_text(encoding="utf-8"))
            token = data.get("root_token")

    if not token:
        print("Error: No Vault token found. Set VAULT_TOKEN, run 'vault login', or pass --vault-token.")
        sys.exit(1)

    env_path = Path(args.env_file)
    secrets = parse_env_file(env_path)
    if not secrets:
        print(f"No key-value pairs found in {env_path}")
        sys.exit(1)

    push_to_vault(args.vault_url, token, args.path, secrets, mount_point=args.mount)


if __name__ == "__main__":
    main()
