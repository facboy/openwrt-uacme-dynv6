#!/bin/sh

SCRIPT_DIR="$(dirname -- $(readlink -f -- "$0"))"

cd "${SCRIPT_DIR}"
wget -O "dns_dynv6.sh" "https://raw.githubusercontent.com/acmesh-official/acme.sh/master/dnsapi/dns_dynv6.sh"
