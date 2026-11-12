#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
catalog_file="${1:-$project_root/strategy-catalog.json}"
signature_file="${2:-$project_root/strategy-catalog.json.sig}"
private_key="${PALKA_CATALOG_PRIVATE_KEY:-}"

if [[ -z "$private_key" || ! -f "$private_key" ]]; then
    echo "error: Ed25519 private key not found: $private_key" >&2
    echo "set PALKA_CATALOG_PRIVATE_KEY to an Ed25519 PEM private key" >&2
    exit 1
fi

temporary_signature="$(mktemp -t palkadpi-catalog-signature.XXXXXX)"
temporary_encoded_signature="$(mktemp -t palkadpi-catalog-encoded-signature.XXXXXX)"
trap 'rm -f "$temporary_signature" "$temporary_encoded_signature"' EXIT

openssl pkeyutl \
    -sign \
    -rawin \
    -inkey "$private_key" \
    -in "$catalog_file" \
    -out "$temporary_signature"

base64 < "$temporary_signature" | tr -d '\n' > "$temporary_encoded_signature"
printf '\n' >> "$temporary_encoded_signature"
swift "$project_root/scripts/validate_strategy_catalog.swift" "$catalog_file" "$temporary_encoded_signature"
cp "$temporary_encoded_signature" "$signature_file"
echo "Signed: $catalog_file"
echo "Signature: $signature_file"
