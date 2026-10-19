#!/bin/sh
set -eu

name="${1:-OpenX11SE Self-Signed}"
out="${2:-openx11se-signing}"
password="${MACOS_CERTIFICATE_PASSWORD:-}"
if [ -z "$password" ]; then
  echo 'Set MACOS_CERTIFICATE_PASSWORD to protect the exported certificate' >&2
  exit 1
fi
if [ -e "$out.p12" ]; then
  echo "$out.p12 already exists" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$work/cert.cnf" \
  -keyout "$work/key.pem" -out "$work/cert.pem"
legacy=''
if openssl version | grep -q '^OpenSSL 3'; then
  legacy='-legacy'
fi
openssl pkcs12 -export $legacy -name "$name" -inkey "$work/key.pem" -in "$work/cert.pem" \
  -out "$out.p12" -passout env:MACOS_CERTIFICATE_PASSWORD
base64 < "$out.p12" | tr -d '\n' > "$out.p12.base64"
echo "$out.p12"
echo "$out.p12.base64"
