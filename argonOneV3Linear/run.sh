#!/usr/bin/with-contenv bashio

###
#Methods - methods called by script
###
##make everything into a float
mkfloat() {
  str=$1
  if [[ $str != *"."* ]]; then
    str=$str".0"
  fi
  echo "$str";
}

##Perform basic checks and return the port number of the detected device.  If the
## device is detected via rudamentary checks, then we will return that exit code.
## otherwise we return 255.
calibrateI2CPort() {
  if [ -z  "$(ls /dev/i2c-*)" ]; then
    echo "Cannot find I2C port.  You must enable I2C for this add-on to operate properly";
    sleep 999999;
    exit 1;
  fi
  for device in /dev/i2c-*; do 
    port=${device:9};
    echo "checking i2c port ${port} at ${device}";
    detection=$(i2cdetect -y "${port}");
    echo "${detection}"
    [[ "${detection}" == *"10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --"* ]] && thePort=${port} && echo "found at $device" && break;
    [[ "${detection}" == *"10: -- -- -- -- -- -- -- -- -- -- -- 1b -- -- -- --"* ]] && thePort=${port} && echo "found at $device" && break;
    echo "not found on ${device}"
  done;
} 


## Float comparison so that we don't need to call non-bash processes
fcomp() {
    local oldIFS="$IFS" op=$2 x y digitx digity
    IFS='.'
    x=( ${1##+([0]|[-]|[+])} )
    y=( ${3##+([0]|[-]|[+])} )
    IFS="$oldIFS"
    while [[ "${x[1]}${y[1]}" =~ [^0] ]]; do
        digitx=${x[1]:0:1}
        digity=${y[1]:0:1}
        (( x[0] = x[0] * 10 + ${digitx:-0} , y[0] = y[0] * 10 + ${digity:-0} ))
        x[1]=${x[1]:1} y[1]=${y[1]:1}
    done
    [[ ${1:0:1} == '-' ]] && (( x[0] *= -1 ))
    [[ ${3:0:1} == '-' ]] && (( y[0] *= -1 ))
    (( "${x:-0}" "$op" "${y:-0}" ))
}

fanSpeedReportLinear(){
  fanPercent=${1}
  cpuTemp=${2}
  CorF=${3}
  icon=mdi:fan
  reqBody='{"state": "'"${fanPercent}"'", "attributes": { "unit_of_measurement": "%", "icon": "'"${icon}"'", "Temperature '"${CorF}"'": "'"${cpuTemp}"'", "friendly_name": "Argon Fan Speed"}}'
  exec 3<>/dev/tcp/hassio/80
  echo -ne "POST /homeassistant/api/states/sensor.argon_one_addon_fan_speed HTTP/1.1\r\n" >&3
  echo -ne "Connection: close\r\n" >&3
  echo -ne "Authorization: Bearer ${SUPERVISOR_TOKEN}\r\n" >&3
  echo -ne "Content-Length: $(echo -ne "${reqBody}" | wc -c)\r\n" >&3
  echo -ne "\r\n" >&3
  echo -ne "${reqBody}" >&3
  timeout=5
  while read -t "${timeout}" -r line; do
        echo "${line}">/dev/null
  done <&3
  exec 3>&-
}

actionLinear() {
  fanPercent=${1};
  cpuTemp=${2};
  CorF=${3};

  if [[ $fanPercent -lt 0 ]]; then
    fanPercent=0
  fi;

  if [[ $fanPercent -gt 100 ]]; then
    fanPercent=100
  fi;

  # send all hexadecimal format 0x00 > 0x64 (0>100%)
  if [[ $fanPercent -lt 10 ]]; then
    fanPercentHex=$(printf '0x0%x' "${fanPercent}")
  else
    fanPercentHex=$(printf '0x%x' "${fanPercent}")
  fi;

  printf '%(%Y-%m-%d_%H:%M:%S)T'
  echo ": ${cpuTemp}${CorF} - Fan ${fanPercent}% | hex:(${fanPercentHex})";
  i2cset -y "${port}" "0x01a" "0x80" "${fanPercentHex}"
  returnValue="${?}"
  test "${createEntity}" == "true" && fanSpeedReportLinear "${fanPercent}" "${cpuTemp}" "${CorF}" &
  return "${returnValue}"
}


tmini=$(jq -r '."Minimum Temperature"' <options.json)
tmaxi=$(jq -r '."Maximum Temperature"'<options.json)
CorF=$(jq -r '."Celsius or Fahrenheit"'<options.json)
createEntity=$(jq -r '."Create a Fan Speed entity in Home Assistant"' <options.json)
logTemp=$(jq -r '."Log current temperature every 30 seconds"' <options.json)

###
#initial setup - prepare things for operation
###
fanPercent=-1;
previousFanPercent=-1;

echo "Detecting Layout of i2c, we expect to see \"1a\" here."
calibrateI2CPort;
port=${thePort};
echo "I2C Port ${port}";
#Trap exits and set fan to 100% like a safe mode.
trap 'echo "Failed ${LINENO}: $BASH_COMMAND";i2cset -y ${port} 0x01a 0x63;previousFanLevel=-1;fanLevel=-1; echo Safe Mode Activated!;' ERR EXIT INT TERM




if [ "${port}" == 255 ]; then 
  echo "Argon One V3 was not detected on i2c. Argon One V3 will show a 1a on the i2c bus above. This add-on will not control temperature without a connection to Argon One V3.";
else 
  echo "Settings initialized. Argon One V3 Detected. Beginning monitor.."
fi;

#Counts the number of repetitions so we can set a 10minute count.
thirtySecondsCount=0;
#The human readable percentage of the fan speed
fanPercent=0;

###
#Main Loop - read and react to changes in read temperature
###


value_a=$((100/(tmaxi-tmini)))
value_b=$((-value_a*tmini))

until false; do
  read -r cpuRawTemp < /sys/class/thermal/thermal_zone0/temp #read instead of cat fpr process reduction
  cpuTemp=$(( cpuRawTemp/1000 )) #built-in bash math
  unit="C"

  if [ "$CorF" == "F" ]; then # convert to F
    cpuTemp=$(( ( cpuTemp *  9/5 ) + 32 ));
    unit="F"
  fi

  value=$cpuTemp
  test "${logTemp}" == "true" && echo "Current Temperature = $cpuTemp °$unit"

  fanPercent=$((value_a*value+value_b))
  set +e
  if [ "${previousFanPercent}" != "${fanPercent}" ]; then
    actionLinear "${fanPercent}" "${cpuTemp}" "${CorF}"
    test $? -ne 0 && fanPercent=previousFanPercent
    previousFanPercent=$fanPercent
  fi
  test $((thirtySecondsCount%20)) == 0 && test "${createEntity}" == "true" && fanSpeedReportLinear "${fanPercent}" "${cpuTemp}" "${CorF}"
  sleep 30
  thirtySecondsCount=$((thirtySecondsCount + 1))
  

done
