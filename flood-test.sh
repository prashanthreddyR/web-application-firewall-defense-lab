#!/usr/bin/env bash
# Section 9.1: simple HTTP flood test. Run from the KALI VM, against YOUR lab only.
# Usage: bash scripts/flood-test.sh https://dvwa.local/ [requests] [concurrency]
set -euo pipefail

URL="${1:?Usage: $0 <url> [requests] [concurrency]}"
REQS="${2:-1000}"
CONC="${3:-50}"

command -v ab >/dev/null || sudo apt-get install -y apache2-utils
ab -k -n "$REQS" -c "$CONC" "$URL"
