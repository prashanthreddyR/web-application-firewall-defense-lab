#!/usr/bin/env bash
# Section 6: self-signed certificate for dvwa.local
# Run on the Ubuntu VM:  bash scripts/generate-cert.sh [common-name]
set -euo pipefail

CN="${1:-dvwa.local}"
DIR=/etc/ssl/dvwa

sudo mkdir -p "$DIR"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$DIR/dvwa.key" \
  -out    "$DIR/dvwa.crt" \
  -subj   "/CN=${CN}" \
  -addext "subjectAltName=DNS:${CN},DNS:www.${CN}"

echo "[done] Created $DIR/dvwa.crt and $DIR/dvwa.key"
echo "       Import both into SafeLine WAF (section 7.2)."
