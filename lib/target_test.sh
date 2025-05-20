#!/usr/bin/env bash

. /etc/script_tv/system.env

fail="0"
gfail="0"

function print_result {
    local page=$1
    local line=$2
    local f=$3
    if [[ "_$f" == "_0" ]]; then
        echo -n "info $page === PASS === "
    else
        echo -n "info $page *** FAIL *** "
    fi
    echo "test: $line"
}

function test_ports_local {
    while read -r line; do
        local ss=$(echo "$line" | awk '{ print $1 }')
        local port=$(echo "$line" | awk '{ print $3 }')
        local status=$(timeout 5 nmap -p $port localhost | grep "^$port/.*" | awk '{ print $1" "$2 }')
        if [[ "_$(echo "$status" | awk '{ print $2 }')" == "_open" ]]; then
            echo -n "ok ${ss} ports_local port $status. "
        else
            echo -n "KO ${ss} ports_local $status. ***. "
            fail="1"
            gfail="1"
        fi
        echo $line
    done < /var/${system_unix_name}/data_sheet__open_ports
}

xt=0
function test_svcs {
    local file=$1
    while read -r line; do
        ss=$(echo $line | awk '{ print $1 }')
        svc=$(echo $line | awk '{ print $2 }')
        local status=$(systemctl status $svc | grep "Active" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
        status=$(echo $status | sed "s/ since.*//")
        echo $status | grep "Active: active"  > /dev/null
	local r=$?
        if [[ $r -eq 0 ]]; then
            echo "ok $ss daemon $svc: $status"
        else
            echo "KO $ss daemon $svc: $status"
            fail="1"
            gfail="1"
        fi
    done < $file
}
if [[ -f /var/${system_unix_name}/data_sheet__shared_daemons ]]; then
	#echo
	#echo "Shared daemons"
	fail="0"
	test_svcs /var/${system_unix_name}/data_sheet__shared_daemons
	print_result 01 "Shared daemons" $fail
fi
if [[ -f /var/${system_unix_name}/data_sheet__daemons ]]; then
	#echo
	#echo "daemons"
	fail="0"
	test_svcs /var/${system_unix_name}/data_sheet__daemons
	print_result 02 "daemons" $fail
fi
if [[ -f /var/${system_unix_name}/data_sheet__open_ports ]]; then
	#echo
	#echo "Ports localhost"
	fail="0"
	test_ports_local
	print_result 03 "localhost nmap" $fail
fi
exit $gfail

