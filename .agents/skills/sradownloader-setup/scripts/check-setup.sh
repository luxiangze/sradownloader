#!/usr/bin/env bash
# check-setup.sh — read-only environment check for sradownloader (v3.11-mod).
# Usage: bash scripts/check-setup.sh [path-to-sradownloader]
#   No argument: tries ./sradownloader, then `sradownloader` on PATH.
# Exit 0: python3 + sradownloader present (downloads can run; NCBI
#   fallback may still be unavailable — see WARN lines).
# Exit 1: python3 or sradownloader missing.
# Installs nothing; only reports.
set -u

fail=0

check_cmd() { # $1 = label, $2 = command name
    if command -v "$2" >/dev/null 2>&1; then
        echo "PASS  $1 ($(command -v "$2"))"
        return 0
    else
        echo "FAIL  $1 (command '$2' not found)"
        return 1
    fi
}

# --- python3 (required) ---
if command -v python3 >/dev/null 2>&1; then
    echo "PASS  python3 ($(python3 --version 2>&1))"
else
    echo "FAIL  python3 (not found; install Python >= 3.6)"
    fail=1
fi

# --- sradownloader (required) ---
SD="${1:-}"
if [ -z "$SD" ]; then
    if [ -x ./sradownloader ]; then SD="./sradownloader";
    elif command -v sradownloader >/dev/null 2>&1; then SD="$(command -v sradownloader)";
    fi
fi
if [ -n "$SD" ] && [ -f "$SD" ]; then
    ver="$(python3 "$SD" --version 2>&1 || true)"
    echo "PASS  sradownloader ($SD; $ver)"
    case "$ver" in
        *3.11-mod*) ;;
        *) echo "WARN  sradownloader version is not 3.11-mod; this fork's skills may not match" ;;
    esac
else
    echo "FAIL  sradownloader (not found; clone https://github.com/luxiangze/sradownloader.git)"
    fail=1
fi

# --- gzip (needed for the NCBI path only) ---
if command -v gzip >/dev/null 2>&1; then
    echo "PASS  gzip ($(gzip --version 2>&1 | head -1))"
else
    echo "WARN  gzip (not found; NCBI fallback disabled, ENA still works)"
fi

# --- fasterq-dump (needed for the NCBI path only) ---
if command -v fasterq-dump >/dev/null 2>&1; then
    echo "PASS  fasterq-dump ($(command -v fasterq-dump); NCBI fallback available)"
else
    echo "WARN  fasterq-dump (not found; NCBI fallback disabled, ENA still works — install SRA Toolkit and run vdb-config -i)"
fi

# --- axel (optional accelerator for ENA) ---
if command -v axel >/dev/null 2>&1; then
    echo "INFO  axel ($(axel --version 2>&1 | head -1); ENA downloads will use axel)"
else
    echo "INFO  axel (not found; built-in FTP downloader with progress bar will be used)"
fi

exit "$fail"
