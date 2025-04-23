UACME_TMP="/tmp/uacme"

load_acme() {
	local dnsapi_sh="$1"

	local acme_stub=
	if [[ -e "${SCRIPT_DIR}/acme_stub.sh" ]]; then
		acme_stub="${SCRIPT_DIR}/acme_stub.sh"
	elif [[ -e "${SCRIPT_DIR}/acme_stub.sh.gz" ]]; then
		acme_stub="${UACME_TMP}/acme_stub.sh"
		if [[ ! -e "${acme_stub}" || "${SCRIPT_DIR}/acme_stub.sh.gz" -nt "${acme_stub}" ]]; then
			gunzip -c "${SCRIPT_DIR}/acme_stub.sh.gz" > "${acme_stub}"
		fi
	else
		>&2 echo "Could not find acme_stub.sh or acme_stub.sh.gz"
		exit 1
	fi

	# fetch to /tmp/uacme and source it from there
	local uptodate_count="$(find "${UACME_TMP}" -mindepth 1 -mtime -1 -name ${dnsapi_sh} | wc -l)"
	if [[ ${uptodate_count} -eq 0 ]]; then
		wget --quiet -O "${UACME_TMP}/${dnsapi_sh}" "https://raw.githubusercontent.com/acmesh-official/acme.sh/master/dnsapi/${dnsapi_sh}"
	fi

	. "${acme_stub}"
	. "${UACME_TMP}/${dnsapi_sh}"
}
