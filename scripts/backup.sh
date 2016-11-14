#!/bin/sh

source /etc/keepalived/scripts/common.sh

[ -n "${state_file}" -a -f "${state_file}" ] && rm -f -- "${state_file}"
