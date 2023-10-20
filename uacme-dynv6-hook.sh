#!/bin/sh
# Copyright (C) 2020 Michel Stam <michel@reverze.net>
# Copyright (C) 2021 Hung-I Wang <whygowe@gmail.com>
# Copyright (C) 2023 Christopher Ng <facboy@gmail.com>
#
# The script is adapted from:
# https://github.com/ndilieto/uacme/blob/5edec0eea1bcf6f454ec1787297c2408c2f2e97a/nsupdate.sh
# and
# https://gist.github.com/Gowee/e756f925cfcbd5ab32d564ee3c795786
#
# Licensed under the the GNU General Public License <http://www.gnu.org/licenses/>.

# The script is meant to be used as a hook script of uacme to update TXT records for acme challenges.
# Instead of relying on IETF RFC2136, it talks to cfapi-ddns-worker.js which is a wrapper around Cloudflare API:
# https://gist.github.com/Gowee/8c3e65b80767b915e0199908e5d7a916

SCRIPT_DIR="$(dirname -- $(readlink -f -- "$0"))"

# vars for acme
PROJECT_NAME="uacme_dynv6-hook.sh"

# load acme functions
. "${SCRIPT_DIR}/acme_stub.sh"
. "${SCRIPT_DIR}/dns_dynv6.sh"

# Arguments
METHOD=$1
TYPE=$2
IDENT=$3
TOKEN=$4
AUTH=$5

ARGS=5
E_BADARGS=85

if [ $# -ne "$ARGS" ]; then
    echo "Usage: $(basename "$0") method type ident token auth" 1>&2
    exit $E_BADARGS
fi

case "$METHOD" in
    "begin")
        case "$TYPE" in
            dns-01)
                dns_dynv6_add "_acme-challenge.$IDENT" "$AUTH"
                exit $?
                ;;
            *)
                exit 1
                ;;
        esac
        ;;

    "done"|"failed")
        case "$TYPE" in
            dns-01)
                dns_dynv6_rm "_acme-challenge.$IDENT"
                exit $?
                ;;
            *)
                exit 1
                ;;
        esac
        ;;

    *)
        echo "$0: invalid method" 1>&2
        exit 1
esac
