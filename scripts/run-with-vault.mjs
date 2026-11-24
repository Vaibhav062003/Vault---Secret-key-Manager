#!/usr/bin/env node
/**
 * Run any command with secrets injected in-memory directly from HashiCorp Vault.
 * Zero files are written to disk.
 *
 * Usage:
 *   node run-with-vault.mjs <secret-path> <command> [args...]
 *
 * Example:
 *   node run-with-vault.mjs dev/heidelai-frontend npm run dev
 */

import { spawn } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("Usage: node run-with-vault.mjs <secret-path> <command> [args...]");
  console.error("Example: node run-with-vault.mjs dev/heidelai-frontend npm run dev");
  process.exit(1);
}

const secretPath = args[0];
const command = args[1];
const commandArgs = args.slice(2);

const vaultAddr = (process.env.VAULT_ADDR || "http://127.0.0.1:8200").replace(/\/$/, "");

// 1. Discover Vault Token
let token = process.env.VAULT_TOKEN;
if (!token) {
  const tokenFile = join(homedir(), ".vault-token");
  if (existsSync(tokenFile)) {
    try {
      token = readFileSync(tokenFile, "utf-8").trim();
    } catch (_) {}
  }
}

if (!token) {
  console.error(`[VaultRunner] Error: No Vault token found. Please run 'vault login' or './dev-login.ps1' first.`);
  process.exit(1);
}

// 2. Fetch secrets from Vault KV v2
async function fetchSecrets() {
  const mount = process.env.VAULT_MOUNT || "kv";
  const url = `${vaultAddr}/v1/${mount}/data/${secretPath}`;

  try {
    const res = await fetch(url, {
      headers: {
        "X-Vault-Token": token,
      },
    });

    if (!res.ok) {
      const errBody = await res.text();
      throw new Error(`Vault returned HTTP ${res.status}: ${errBody}`);
    }

    const json = await res.json();
    const secrets = json?.data?.data || {};
    return secrets;
  } catch (err) {
    console.error(`[VaultRunner] Failed to fetch secrets from ${url}:`, err.message);
    process.exit(1);
  }
}

async function run() {
  console.log(`[VaultRunner] Fetching secrets for '${secretPath}' from ${vaultAddr}...`);
  const secrets = await fetchSecrets();
  const secretKeys = Object.keys(secrets);
  console.log(`[VaultRunner] Loaded ${secretKeys.length} secrets into process memory. Starting '${command} ${commandArgs.join(" ")}'...`);

  const childEnv = {
    ...process.env,
    ...secrets,
  };

  const child = spawn(command, commandArgs, {
    env: childEnv,
    stdio: 'inherit',
    shell: true,
  });

  child.on('exit', (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
    } else {
      process.exit(code ?? 0);
    }
  });
}

run();
