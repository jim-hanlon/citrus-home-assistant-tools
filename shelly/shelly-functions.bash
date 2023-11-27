#!/bin/bash

prg=${BASH_SOURCE[0]}
[[ ( -n "${prg}" ) && ( -f "${prg}" ) ]] || (echo "[FATAL] cannot locate: '$0'" 1>&2)
task=$(basename -- "${prg}")
prgdir=$(dirname -- "${prg}")
prgdir=$(cd "${prgdir}" > /dev/null && pwd)

export CURL="curl --connect-timeout 15 -s"
export DEVICE_DETAILS="${prgdir}/automation-device-details.csv"
export DOMAIN=thehanlons.net
export HA_SERVER=home-assistant-1.${DOMAIN}
export MQTT_SERVER=${HA_SERVER}:1883
export MQTT_USER=mqtt
export MQTT_PASSWORD='93Medicare#!/bin/Botanical'
export COIOT_PEER=$(dig +short "${HA_SERVER}"):5683
export SNTP_SERVER=firewall.${DOMAIN}

function device_details() {
    local host=${1:-}
    if [[ -z "${host}" ]]; then
        device_details_all
    else
        device_details_all | grep "${host}"
    fi
}

function envvar() {
	echo -n "${1}" | tr [a-z] [A-Z] | tr -c [A-Z0-9] _
}

function device-url() {
    local host=${1:-${SHELLY:?Need device hostname}}
    host=$(echo "${host}" | cut -d. -f1) # Remove domain
    var=SHELLY_IP_$(envvar "${host}")
    host=${!var:-${SHELLY_IP:-${host}.${DOMAIN}}}
    echo "http://${host}"
}

function shelly-device-details-all() {
    cat "${DEVICE_DETAILS}" | tail -n +2 
}

function shelly-devices() {
    shelly-device-details-all | cut -d, -f1 | tr A-Z a-z
}

function mqtt-config-element () {
    local element=${1:?Need element name}
    local host=${2:-${SHELLY:?Need device hostname}}
    curl -s http://${host}/rpc/MQTT.GetConfig | jq '.["'${element}'"]' | sed 's/"//g'
}

function shellyplus1-device-details-all() {
    shelly-device-details-all | grep shellyplus1
}

function shellyplus1-devices() {
    shellyplus1-device-details-all | cut -d, -f1 | tr A-Z a-z
}

function shellyplus1-initialize() {
    local host=${1:-${SHELLY:?Need hostname}}
    local rpc=http://$(device-url '${host}')/rpc
    local sys_cmd=$(printf '{"id":1,"method":"Sys.SetConfig","params":{"config":{"device":{"name":"%s","discoverable":true}},"sntp":{"server":"%s"}}}' "${host}" "${SNTP_SERVER}")
    local sys_result=$(${CURL} -X POST -d "${sys_cmd}" "${rpc}")
    local cloud_cmd=$(printf '{"id":1,"method":"Cloud.SetConfig","params":{"config":{"enable":false}}}')
    local cloud_result=$(${CURL} -X POST -d "${cloud_cmd}" "${rpc}")
    local mqtt_cmd=$(printf '{"id":1,"method":"MQTT.SetConfig","params":{"config":{"enable":true,"server":"%s","client_id":"%s","topic_prefix":"%s","user":"%s","enable_control":true,"pass":"%s"}}}'  "${MQTT_SERVER}" "${host}" "${host}" "${MQTT_USER}" "${MQTT_PASSWORD}")
    local mqtt_result=$(${CURL} -X POST -d "${mqtt_cmd}" "${rpc}")
    local ble_cmd=$(printf '{"id":1,"method":"BLE.SetConfig","params":{"config":{"enable":false,"rpc":{"enable":false},"observer":{"enable":false}}}')
    local ble_result=$(${CURL} -X POST -d "${ble_cmd}" "${rpc}")

    if [[ $(echo "${sys_result}" | jq '.result.restart_required') == 'true' ]] || \
       [[ $(echo "${cloud_result}" | jq '.result.restart_required') == 'true' ]] || \
       [[ $(echo "${mqtt_result}" | jq '.result.restart_required') == 'true' ]] || \
       [[ $(echo "${ble_result}" | jq '.result.restart_required') == 'true' ]] ; then
        shellyplus1-reboot "${host}"
        sleep 5
    fi
    shellyplus1-status "${host}"
}

function shellyplus1-initialize-all() {
    __shellyplus1-device-iterate initialize
}

function shellyplus1-reboot() {
    ${CURL} "$(device-url ${1})/rpc/Shelly.Reboot"
}

function shellyplus1-reboot-all() {
    __shellyplus1-device-iterate reboot
}

function shellyplus1-config() {
    local rpc=$(device-url ${1})/rpc
    local result='{'
    result+='"device":'$(${CURL} "${rpc}/Shelly.GetDeviceInfo")
    result+=',"shelly":'$(${CURL} "${rpc}/Shelly.GetConfig")
    # result+=',"system":'$(${CURL} "${rpc}/Sys.GetConfig")
    # result+=',"wifi":'$(${CURL} "${rpc}/WiFi.GetConfig")
    # result+=',"ble":'$(${CURL} "${rpc}/BLE.GetConfig")
    # result+=',"mqtt":'$(${CURL} "${rpc}/MQTT.GetConfig")
    # result+=',"cloud":'$(${CURL} "${rpc}/Cloud.GetConfig")
    # result+=',"input":'$(${CURL} -X POST -d '{"id":1,"method":"Input.GetConfig","params":{"id":0}}' "${rpc}")
    # result+=',"switch":'$(${CURL} -X POST -d '{"id":1,"method":"Switch.GetConfig","params":{"id":0}}' "${rpc}")
    result+='}'
    echo "${result}"
}

function shellyplus1-status() {
    local rpc=$(device-url ${1})/rpc
    local result='{'
    result+='"shelly":'$(${CURL} "${rpc}/Shelly.GetStatus")
    result+=',"system":'$(${CURL} "${rpc}/Sys.GetStatus")
    # result+=',"wifi":'$(${CURL} "${rpc}/WiFi.GetStatus")
    # result+=',"ble":'$(${CURL} "${rpc}/BLE.GetStatus")
    # result+=',"mqtt":'$(${CURL} "${rpc}/MQTT.GetStatus")
    # result+=',"cloud":'$(${CURL} "${rpc}/Cloud.GetStatus")
    # result+=',"input":'$(${CURL} -X POST -d '{"id":1,"method":"Input.GetStatus","params":{"id":0}}' "${rpc}")
    # result+=',"switch":'$(${CURL} -X POST -d '{"id":1,"method":"Switch.GetStatus","params":{"id":0}}' "${rpc}")
    result+='}'
    echo "${result}"
}

function shellyplus1-status-all() {
    __shellyplus1-device-iterate status
}

function shellydimmer2-device-details-all() {
    shelly-device-details-all | grep shellydimmer2
}

function shellydimmer2-devices() {
    shellydimmer2-device-details-all | cut -d, -f1 
}

function shellydimmer2-initialize() {
    local host=${1:-${SHELLY:?Need hostname}}
    local setting_url="$(device-url '${host}')/settings?name=${host}"
    setting_url+="&mqtt_enable=true"
    setting_url+="&mqtt_server=$(urlencode ${MQTT_SERVER})"
    setting_url+="&mqtt_id=${host}"
    setting_url+="&max_qos=2"
    setting_url+="&mqtt_user=$(urlencode ${MQTT_USER})"
    setting_url+="&mqtt_pass=$(urlencode ${MQTT_PASSWORD})"
    setting_url+="&coiot.enabled=true"
    setting_url+="&coiot_peer=$(urlencode ${COIOT_PEER})"
    setting_url+="&cloud.enabled=false"
    setting_url+="&sntp_server=$(urlencode ${SNTP_SERVER})"
    setting_url+="&discoverable=true"
    setting_url+="&allow_cross_origin=false"
    setting_url+="&eco_mode_enabled=false"

    local light_url="$(device-url '${host}')/light/0?name=${host}"
    light_url+="&default_state=last"
    light_url+="&btn_type=detached"

    local setting_response=$(${CURL} "${setting_url}")
    # echo ${setting_response}
    local light_response=$(${CURL} "${light_url}")
    # echo ${light_response}
    
    shellydimmer2-reboot "${host}"
    sleep 5
    shellydimmer2-status "${host}"
}

function shellydimmer2-initialize-all() {
    __shellydimmer2-device-iterate initialize
}

function shellydimmer2-reboot() {
    ${CURL} "$(device-url ${1})/reboot"
}

function shellydimmer2-reboot-all() {
    __shellydimmer2-device-iterate reboot
}

function shellydimmer2-setting() {
    ${CURL} "$(device-url ${1})/settings"
}

function shellydimmer2-setting-all() {
    __shellydimmer2-device-iterate setting
}

function shellydimmer2-show-missing-hosts() {
    local s=
    shellydimmer2-device-details-all | cut -f1 -d, | tr [A-Z] [a-z] | while read host; do
       s=$(shellydimmer2-status "${host}")
       if [ -z "${s}" ]; then
           echo "${host}"
       fi
    done
}

function shellydimmer2-status() {
    ${CURL} "$(device-url ${1})/status"
}

function shellydimmer2-status-all() {
    __shellydimmer2-device-iterate status
}

function urlencode() {
  LC_ALL=C awk -- '
    BEGIN {
      for (i = 1; i <= 255; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i)
    }
    function urlencode(s,  c,i,r,l) {
      l = length(s)
      for (i = 1; i <= l; i++) {
        c = substr(s, i, 1)
        r = r "" (c ~ /^[-._~0-9a-zA-Z]$/ ? c : hex[c])
      }
      return r
    }
    BEGIN {
      for (i = 1; i < ARGC; i++)
        print urlencode(ARGV[i])
    }' "$@"
}

function __shellyplus1-device-iterate() {
    __shelly-device-iterate shellyplus1 "${@}"
}

function __shellydimmer2-device-iterate() {
    __shelly-device-iterate shellydimmer2 "${@}"
}

function __shelly-device-iterate() {
    local family=${1:?Need family}
    shift
    local f=${1:?Need command}
    shift
    echo -n '{'
    local d=
    ${family}-devices | while read host; do
        echo -n "${d}\"${host}\":"
        ${family}-${f} "${host}" "${@}"
        d=,
    done
    echo '}'
}

