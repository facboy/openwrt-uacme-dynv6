# Stripped back version of acme.sh from
#   https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
# Contains just enough to allow dns_dynv6.sh to run and dns_cf.sh to run

LOG_LEVEL_1=1
LOG_LEVEL_2=2
LOG_LEVEL_3=3
DEFAULT_LOG_LEVEL="$LOG_LEVEL_2"

DEBUG_LEVEL_1=1
DEBUG_LEVEL_2=2
DEBUG_LEVEL_3=3
DEBUG_LEVEL_DEFAULT=$DEBUG_LEVEL_2
DEBUG_LEVEL_NONE=0

SYSLOG_ERROR="user.error"
SYSLOG_INFO="user.info"
SYSLOG_DEBUG="user.debug"

#error
SYSLOG_LEVEL_ERROR=3
#info
SYSLOG_LEVEL_INFO=6
#debug
SYSLOG_LEVEL_DEBUG=7
#debug2
SYSLOG_LEVEL_DEBUG_2=8
#debug3
SYSLOG_LEVEL_DEBUG_3=9

SYSLOG_LEVEL_DEFAULT=$SYSLOG_LEVEL_ERROR
#none
SYSLOG_LEVEL_NONE=0

SYS_LOG=${SYS_LOG:-$SYSLOG_LEVEL_DEFAULT}
# disable logging to file
LOG_FILE=
# disable debug to stderr
DEBUG=

__green() {
  if [ "${__INTERACTIVE}${ACME_NO_COLOR:-0}" = "10" -o "${ACME_FORCE_COLOR}" = "1" ]; then
    printf '\33[1;32m%b\33[0m' "$1"
    return
  fi
  printf -- "%b" "$1"
}

__red() {
  if [ "${__INTERACTIVE}${ACME_NO_COLOR:-0}" = "10" -o "${ACME_FORCE_COLOR}" = "1" ]; then
    printf '\33[1;31m%b\33[0m' "$1"
    return
  fi
  printf -- "%b" "$1"
}

_printargs() {
  _exitstatus="$?"
  if [ -z "$NO_TIMESTAMP" ] || [ "$NO_TIMESTAMP" = "0" ]; then
    printf -- "%s" "[$(date)] "
  fi
  if [ -z "$2" ]; then
    printf -- "%s" "$1"
  else
    printf -- "%s" "$1='$2'"
  fi
  printf "\n"
  # return the saved exit status
  return "$_exitstatus"
}

#class
_syslog() {
  _exitstatus="$?"
  if [ "${SYS_LOG:-$SYSLOG_LEVEL_NONE}" = "$SYSLOG_LEVEL_NONE" ]; then
    return
  fi
  _logclass="$1"
  shift
  if [ -z "$__logger_i" ]; then
    if _contains "$(logger --help 2>&1)" "-i"; then
      __logger_i="logger -i"
    else
      __logger_i="logger"
    fi
  fi
  $__logger_i -t "$PROJECT_NAME" -p "$_logclass" "$(_printargs "$@")" >/dev/null 2>&1
  return "$_exitstatus"
}

_log() {
  [ -z "$LOG_FILE" ] && return
  _printargs "$@" >>"$LOG_FILE"
}

_info() {
  _log "$@"
  if [ "${SYS_LOG:-$SYSLOG_LEVEL_NONE}" -ge "$SYSLOG_LEVEL_INFO" ]; then
    _syslog "$SYSLOG_INFO" "$@"
  fi
  _printargs "$@"
}

_err() {
  _syslog "$SYSLOG_ERROR" "$@"
  _log "$@"
  if [ -z "$NO_TIMESTAMP" ] || [ "$NO_TIMESTAMP" = "0" ]; then
    printf -- "%s" "[$(date)] " >&2
  fi
  if [ -z "$2" ]; then
    __red "$1" >&2
  else
    __red "$1='$2'" >&2
  fi
  printf "\n" >&2
  return 1
}

__debug_bash_helper() {
  # At this point only do for --debug 3
  if [ "${DEBUG:-$DEBUG_LEVEL_NONE}" -lt "$DEBUG_LEVEL_3" ]; then
    return
  fi
  # Return extra debug info when running with bash, otherwise return empty
  # string.
  if [ -z "${BASH_VERSION}" ]; then
    return
  fi
  # We are a bash shell at this point, return the filename, function name, and
  # line number as a string
  _dbh_saveIFS=$IFS
  IFS=" "
  # Must use eval or syntax error happens under dash. The eval should use
  # single quotes as older versions of busybox had a bug with double quotes and
  # eval.
  # Use 'caller 1' as we want one level up the stack as we should be called
  # by one of the _debug* functions
  eval '_dbh_called=($(caller 1))'
  IFS=$_dbh_saveIFS
  eval '_dbh_file=${_dbh_called[2]}'
  if [ -n "${_script_home}" ]; then
    # Trim off the _script_home directory name
    eval '_dbh_file=${_dbh_file#$_script_home/}'
  fi
  eval '_dbh_function=${_dbh_called[1]}'
  eval '_dbh_lineno=${_dbh_called[0]}'
  printf "%-40s " "$_dbh_file:${_dbh_function}:${_dbh_lineno}"
}

_debug() {
  if [ "${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}" -ge "$LOG_LEVEL_1" ]; then
    _log "$@"
  fi
  if [ "${SYS_LOG:-$SYSLOG_LEVEL_NONE}" -ge "$SYSLOG_LEVEL_DEBUG" ]; then
    _syslog "$SYSLOG_DEBUG" "$@"
  fi
  if [ "${DEBUG:-$DEBUG_LEVEL_NONE}" -ge "$DEBUG_LEVEL_1" ]; then
    _bash_debug=$(__debug_bash_helper)
    _printargs "${_bash_debug}$@" >&2
  fi
}

_debug2() {
  if [ "${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}" -ge "$LOG_LEVEL_2" ]; then
    _log "$@"
  fi
  if [ "${SYS_LOG:-$SYSLOG_LEVEL_NONE}" -ge "$SYSLOG_LEVEL_DEBUG_2" ]; then
    _syslog "$SYSLOG_DEBUG" "$@"
  fi
  if [ "${DEBUG:-$DEBUG_LEVEL_NONE}" -ge "$DEBUG_LEVEL_2" ]; then
    _bash_debug=$(__debug_bash_helper)
    _printargs "${_bash_debug}$@" >&2
  fi
}

_debug3() {
  if [ "${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}" -ge "$LOG_LEVEL_3" ]; then
    _log "$@"
  fi
  if [ "${SYS_LOG:-$SYSLOG_LEVEL_NONE}" -ge "$SYSLOG_LEVEL_DEBUG_3" ]; then
    _syslog "$SYSLOG_DEBUG" "$@"
  fi
  if [ "${DEBUG:-$DEBUG_LEVEL_NONE}" -ge "$DEBUG_LEVEL_3" ]; then
    _bash_debug=$(__debug_bash_helper)
    _printargs "${_bash_debug}$@" >&2
  fi
}

_contains() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

_exists() {
  cmd="$1"
  if [ -z "$cmd" ]; then
    _usage "Usage: _exists cmd"
    return 1
  fi

  if eval type type >/dev/null 2>&1; then
    eval type "$cmd" >/dev/null 2>&1
  elif command >/dev/null 2>&1; then
    command -v "$cmd" >/dev/null 2>&1
  else
    which "$cmd" >/dev/null 2>&1
  fi
  ret="$?"
  _debug3 "$cmd exists=$ret"
  return $ret
}

#options file
_sed_i() {
  options="$1"
  filename="$2"
  if [ -z "$filename" ]; then
    _usage "Usage:_sed_i options filename"
    return 1
  fi
  _debug2 options "$options"
  if sed -h 2>&1 | grep "\-i\[SUFFIX]" >/dev/null 2>&1; then
    _debug "Using sed  -i"
    sed -i "$options" "$filename"
  else
    _debug "No -i support in sed"
    text="$(cat "$filename")"
    echo "$text" | sed "$options" >"$filename"
  fi
}

if [ "$(echo abc | egrep -o b 2>/dev/null)" = "b" ]; then
  __USE_EGREP=1
else
  __USE_EGREP=""
fi

_egrep_o() {
  if [ "$__USE_EGREP" ]; then
    egrep -o -- "$1" 2>/dev/null
  else
    sed -n 's/.*\('"$1"'\).*/\1/p'
  fi
}

_time() {
  date -u "+%s"
}

_mktemp() {
  if _exists mktemp; then
    if mktemp 2>/dev/null; then
      return 0
    elif _contains "$(mktemp 2>&1)" "-t prefix" && mktemp -t "$PROJECT_NAME" 2>/dev/null; then
      #for Mac osx
      return 0
    fi
  fi
  if [ -d "/tmp" ]; then
    echo "/tmp/${PROJECT_NAME}wefADf24sf.$(_time).tmp"
    return 0
  elif [ "$LE_TEMP_DIR" ] && mkdir -p "$LE_TEMP_DIR"; then
    echo "/$LE_TEMP_DIR/wefADf24sf.$(_time).tmp"
    return 0
  fi
  _err "Can not create temp file."
}

_inithttp() {

  if [ -z "$HTTP_HEADER" ] || ! touch "$HTTP_HEADER"; then
    HTTP_HEADER="$(_mktemp)"
    _debug2 HTTP_HEADER "$HTTP_HEADER"
  fi

  if [ "$__HTTP_INITIALIZED" ]; then
    if [ "$_ACME_CURL$_ACME_WGET" ]; then
      _debug2 "Http already initialized."
      return 0
    fi
  fi

  if [ -z "$_ACME_CURL" ] && _exists "curl"; then
    _ACME_CURL="curl --silent --dump-header $HTTP_HEADER "
    if [ -z "$ACME_HTTP_NO_REDIRECTS" ]; then
      _ACME_CURL="$_ACME_CURL -L "
    fi
    if [ "$DEBUG" ] && [ "$DEBUG" -ge 2 ]; then
      _CURL_DUMP="$(_mktemp)"
      _ACME_CURL="$_ACME_CURL --trace-ascii $_CURL_DUMP "
    fi

    if [ "$CA_PATH" ]; then
      _ACME_CURL="$_ACME_CURL --capath $CA_PATH "
    elif [ "$CA_BUNDLE" ]; then
      _ACME_CURL="$_ACME_CURL --cacert $CA_BUNDLE "
    fi

    if _contains "$(curl --help 2>&1)" "--globoff" || _contains "$(curl --help curl 2>&1)" "--globoff"; then
      _ACME_CURL="$_ACME_CURL -g "
    fi

    #don't use --fail-with-body
    ##from curl 7.76: return fail on HTTP errors but keep the body
    #if _contains "$(curl --help http 2>&1)" "--fail-with-body"; then
    #  _ACME_CURL="$_ACME_CURL --fail-with-body "
    #fi
  fi

  if [ -z "$_ACME_WGET" ] && _exists "wget"; then
    _ACME_WGET="wget -q"
    if [ "$ACME_HTTP_NO_REDIRECTS" ]; then
      _ACME_WGET="$_ACME_WGET --max-redirect 0 "
    fi
    if [ "$DEBUG" ] && [ "$DEBUG" -ge "2" ]; then
      if [ "$_ACME_WGET" ] && _contains "$($_ACME_WGET --help 2>&1)" "--debug"; then
        _ACME_WGET="$_ACME_WGET -d "
      fi
    fi
    if [ "$CA_PATH" ]; then
      _ACME_WGET="$_ACME_WGET --ca-directory=$CA_PATH "
    elif [ "$CA_BUNDLE" ]; then
      _ACME_WGET="$_ACME_WGET --ca-certificate=$CA_BUNDLE "
    fi

    #from wget 1.14: do not skip body on 404 error
    if _contains "$(wget --help 2>&1)" "--content-on-error"; then
      _ACME_WGET="$_ACME_WGET --content-on-error "
    fi
  fi

  __HTTP_INITIALIZED=1

}

# body  url [needbase64] [POST|PUT|DELETE] [ContentType]
_post() {
  body="$1"
  _post_url="$2"
  needbase64="$3"
  httpmethod="$4"
  _postContentType="$5"

  if [ -z "$httpmethod" ]; then
    httpmethod="POST"
  fi
  _debug $httpmethod
  _debug "_post_url" "$_post_url"
  _debug2 "body" "$body"
  _debug2 "_postContentType" "$_postContentType"

  _inithttp

  if [ "$_ACME_CURL" ] && [ "${ACME_USE_WGET:-0}" = "0" ]; then
    _CURL="$_ACME_CURL"
    if [ "$HTTPS_INSECURE" ]; then
      _CURL="$_CURL --insecure  "
    fi
    if [ "$httpmethod" = "HEAD" ]; then
      _CURL="$_CURL -I  "
    fi
    _debug "_CURL" "$_CURL"
    if [ "$needbase64" ]; then
      if [ "$body" ]; then
        if [ "$_postContentType" ]; then
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "Content-Type: $_postContentType" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" --data "$body" "$_post_url" | _base64)"
        else
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" --data "$body" "$_post_url" | _base64)"
        fi
      else
        if [ "$_postContentType" ]; then
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "Content-Type: $_postContentType" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$_post_url" | _base64)"
        else
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$_post_url" | _base64)"
        fi
      fi
    else
      if [ "$body" ]; then
        if [ "$_postContentType" ]; then
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "Content-Type: $_postContentType" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" --data "$body" "$_post_url")"
        else
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" --data "$body" "$_post_url")"
        fi
      else
        if [ "$_postContentType" ]; then
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "Content-Type: $_postContentType" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$_post_url")"
        else
          response="$($_CURL --user-agent "$USER_AGENT" -X $httpmethod -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$_post_url")"
        fi
      fi
    fi
    _ret="$?"
    if [ "$_ret" != "0" ]; then
      _err "Please refer to https://curl.haxx.se/libcurl/c/libcurl-errors.html for error code: $_ret"
      if [ "$DEBUG" ] && [ "$DEBUG" -ge "2" ]; then
        _err "Here is the curl dump log:"
        _err "$(cat "$_CURL_DUMP")"
      fi
    fi
  elif [ "$_ACME_WGET" ]; then
    _WGET="$_ACME_WGET"
    if [ "$HTTPS_INSECURE" ]; then
      _WGET="$_WGET --no-check-certificate "
    fi
    if [ "$httpmethod" = "HEAD" ]; then
      _WGET="$_WGET --read-timeout=3.0  --tries=2  "
    fi
    _debug "_WGET" "$_WGET"
    if [ "$needbase64" ]; then
      if [ "$httpmethod" = "POST" ]; then
        if [ "$_postContentType" ]; then
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --header "Content-Type: $_postContentType" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER" | _base64)"
        else
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER" | _base64)"
        fi
      else
        if [ "$_postContentType" ]; then
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --header "Content-Type: $_postContentType" --method $httpmethod --body-data="$body" "$_post_url" 2>"$HTTP_HEADER" | _base64)"
        else
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --method $httpmethod --body-data="$body" "$_post_url" 2>"$HTTP_HEADER" | _base64)"
        fi
      fi
    else
      if [ "$httpmethod" = "POST" ]; then
        if [ "$_postContentType" ]; then
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --header "Content-Type: $_postContentType" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        else
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        fi
      elif [ "$httpmethod" = "HEAD" ]; then
        if [ "$_postContentType" ]; then
          response="$($_WGET --spider -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --header "Content-Type: $_postContentType" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        else
          response="$($_WGET --spider -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --post-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        fi
      else
        if [ "$_postContentType" ]; then
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --header "Content-Type: $_postContentType" --method $httpmethod --body-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        else
          response="$($_WGET -S -O - --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" --method $httpmethod --body-data="$body" "$_post_url" 2>"$HTTP_HEADER")"
        fi
      fi
    fi
    _ret="$?"
    if [ "$_ret" = "8" ]; then
      _ret=0
      _debug "wget returns 8, the server returns a 'Bad request' response, lets process the response later."
    fi
    if [ "$_ret" != "0" ]; then
      _err "Please refer to https://www.gnu.org/software/wget/manual/html_node/Exit-Status.html for error code: $_ret"
    fi
    if _contains "$_WGET" " -d "; then
      # Demultiplex wget debug output
      cat "$HTTP_HEADER" >&2
      _sed_i '/^[^ ][^ ]/d; /^ *$/d' "$HTTP_HEADER"
    fi
    # remove leading whitespaces from header to match curl format
    _sed_i 's/^  //g' "$HTTP_HEADER"
  else
    _ret="$?"
    _err "Neither curl nor wget is found, can not do $httpmethod."
  fi
  _debug "_ret" "$_ret"
  printf "%s" "$response"
  return $_ret
}

# url getheader timeout
_get() {
  _debug GET
  url="$1"
  onlyheader="$2"
  t="$3"
  _debug url "$url"
  _debug "timeout=$t"

  _inithttp

  if [ "$_ACME_CURL" ] && [ "${ACME_USE_WGET:-0}" = "0" ]; then
    _CURL="$_ACME_CURL"
    if [ "$HTTPS_INSECURE" ]; then
      _CURL="$_CURL --insecure  "
    fi
    if [ "$t" ]; then
      _CURL="$_CURL --connect-timeout $t"
    fi
    _debug "_CURL" "$_CURL"
    if [ "$onlyheader" ]; then
      $_CURL -I --user-agent "$USER_AGENT" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$url"
    else
      $_CURL --user-agent "$USER_AGENT" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$url"
    fi
    ret=$?
    if [ "$ret" != "0" ]; then
      _err "Please refer to https://curl.haxx.se/libcurl/c/libcurl-errors.html for error code: $ret"
      if [ "$DEBUG" ] && [ "$DEBUG" -ge "2" ]; then
        _err "Here is the curl dump log:"
        _err "$(cat "$_CURL_DUMP")"
      fi
    fi
  elif [ "$_ACME_WGET" ]; then
    _WGET="$_ACME_WGET"
    if [ "$HTTPS_INSECURE" ]; then
      _WGET="$_WGET --no-check-certificate "
    fi
    if [ "$t" ]; then
      _WGET="$_WGET --timeout=$t"
    fi
    _debug "_WGET" "$_WGET"
    if [ "$onlyheader" ]; then
      _wget_out="$($_WGET --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" -S -O /dev/null "$url" 2>&1)"
      if _contains "$_WGET" " -d "; then
        # Demultiplex wget debug output
        echo "$_wget_out" >&2
        echo "$_wget_out" | sed '/^[^ ][^ ]/d; /^ *$/d; s/^  //g' -
      fi
    else
      $_WGET --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" -S -O - "$url" 2>"$HTTP_HEADER"
      if _contains "$_WGET" " -d "; then
        # Demultiplex wget debug output
        cat "$HTTP_HEADER" >&2
        _sed_i '/^[^ ][^ ]/d; /^ *$/d' "$HTTP_HEADER"
      fi
      # remove leading whitespaces from header to match curl format
      _sed_i 's/^  //g' "$HTTP_HEADER"
    fi
    ret=$?
    if [ "$ret" = "8" ]; then
      ret=0
      _debug "wget returns 8, the server returns a 'Bad request' response, lets process the response later."
    fi
    if [ "$ret" != "0" ]; then
      _err "Please refer to https://www.gnu.org/software/wget/manual/html_node/Exit-Status.html for error code: $ret"
    fi
  else
    ret=$?
    _err "Neither curl nor wget is found, can not do GET."
  fi
  _debug "ret" "$ret"
  return $ret
}

_head_n() {
  head -n "$1"
}

_savedomainconf() {
  # noop, don't save anything
  return 0
}

_saveaccountconf_mutable() {
  # noop, don't save anything
  return 0
}

_readaccountconf_mutable() {
  _err "_readaccountconf_mutable() should never be called, exiting..."
  exit 1
}
