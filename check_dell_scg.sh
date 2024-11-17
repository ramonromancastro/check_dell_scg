#!/bin/bash
#
# check_dell_scg.sh is a bash function to check DELL Secure Connect Gateway
# Copyright (C) 2024 Ramon Roman Castro <ramonromancastro@gmail.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
#
# @package    nagios-plugins
# @author     Ramon Roman Castro <ramonromancastro@gmail.com>
# @link       http://www.rrc2software.com
# @link       https://github.com/ramonromancastro/check_dell_scg

HOSTNAME=localhost
DOMAIN=localhost
USERNAME=
PASSWORD=
PORT=5700

VERSION='0.3'

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

NAGIOS_STATUS=$NAGIOS_OK

set_nagios_status(){
    status=$1
    if [[ $status == $NAGIOS_CRITICAL ]]; then
        NAGIOS_STATUS=$status
    elif [[ $status == $NAGIOS_WARNING && $NAGIOS_STATUS != $NAGIOS_CRITICAL ]]; then
        NAGIOS_STATUS=$status
    elif [[ $status == $NAGIOS_UNKNOWN && $NAGIOS_STATUS != $NAGIOS_CRITICAL && $NAGIOS_STATUS != $NAGIOS_WARNING ]]; then
        NAGIOS_STATUS=$status
    else
        NAGIOS_STATUS=$status
    fi
}

function print_version(){
        echo "check_dell_scg.sh - version $VERSION"
        exit $NAGIOS_OK
}

function print_help(){
        echo "check_dell_scg.sh"
        echo ""

        echo "This plugin is not developped by the Nagios Plugin group."
        echo "Please do not e-mail them for support on this plugin."
        echo ""
        echo "For contact info, please read the plugin script file."
        echo ""
        echo "Usage: check_dell_scg.sh -H <hostname> [-h] [-V]"
        echo "------------------------------------------------------------------------------------"
        echo "Usable Options:"
        echo ""
        echo "   -H <hostname>   ... Name or IP address of host to check (default: localhost)"
        echo "   -p <port>       ... Name or IP address of host to check (default: 5700)"
        echo "   -u <username>   ... Authentication user"
        echo "   -P <password>   ... Authentication password"
        echo "   -d <domain>     ... Domain (default: localhost)"
        echo "   -h              ... Show this help screen"
        echo "   -V              ... Show the current version of the plugin"
        echo ''
        echo 'Examples:'
        echo "    check_dell_scg.sh -h 127.0.0.1 -u nagios -P P@\$\$w0rd"
        echo "    check_dell_scg.sh -V"
        echo ""
        echo "------------------------------------------------------------------------------------"
        exit $NAGIOS_OK
}

check_json_error(){
    JSON=$1
    ACTION=$2
    if [ -z "$JSON" ]; then
        echo "ERROR accessing $ACTION"
        exit $NAGIOS_UNKNOWN
    fi

    error_type=$(echo "$JSON" | jq -r '.type')
    if [ "$error_type" == "ERROR" ]; then
        echo "ERROR reading $ACTION"
        exit $NAGIOS_UNKNOWN
    fi
}

# Read command line options
while getopts "H:p:u:P:d:hV" OPTNAME;
do
    case $OPTNAME in
        "H")
            HOSTNAME=$OPTARG;;
        "p")
            PORT=$OPTARG;;
        "u")
            USERNAME=$OPTARG;;
        "P")
            PASSWORD=$OPTARG;;
        "d")
            DOMAIN=$OPTARG;;
        "h")
            print_help;;
        "V")
            print_version;;
        *)
            print_help;;
    esac
done


JSON=$(curl --silent --insecure -L --header "Accept: application/json" --header "Content-Type: application/json" --data '{"domain":"'$DOMAIN'","username":"'$USERNAME'","password":"'$PASSWORD'"}' https://$HOSTNAME:$PORT/SupportAssist/api/v2/auth/token)
check_json_error "$JSON" "accessToken"
ACCESS_TOKEN=$(echo $JSON | jq -r '.accessToken')

JSON=$(curl --silent --insecure -L --header "Authorization: Bearer $ACCESS_TOKEN" --header "Content-Type: application/json" https://$HOSTNAME:$PORT/SupportAssist/api/v2/service/healthstatus?emailOptin=no)
check_json_error "$JSON" "healthStatus"

echo $JSON | jq '.. | select(.status? // empty | ascii_downcase | IN("healthy", "running", "connected") | not) | "ERROR"' | grep "ERROR" > /dev/null 2>&1 && set_nagios_status $NAGIOS_WARNING || set_nagios_status $NAGIOS_OK

case $NAGIOS_STATUS in
  $NAGIOS_OK)
    echo "OK: Todo está correcto"
    ;;
  $NAGIOS_WARNING)
    echo "WARNING: Uno o más valores de status están en aviso"
    ;;
esac
