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


fanSpeedReport(){
  fanPercent=${1}
  fanLevel=${2}
  fanMode=${3}
  cpuTemp=${4}
  CorF=${5}
  case ${fanLevel} in
    1)
      icon=mdi:fan;
      ;;
    2)
      icon=mdi:fan-speed-1;
      ;;
    3)
      icon=mdi:fan-speed-2;
      ;;
    4)
      icon=mdi:fan-speed-3;
      ;;
    *)
      icon=mdi:fan;
  esac
  reqBody='{"state": "'"${fanPercent}"'", "attributes": { "unit_of_measurement": "%", "icon": "'"${icon}"'", "mode": "'"${fanMode}"'", "Temperature '"${CorF}"'": "'"${cpuTemp}"'", "fan level": "'"${fanLevel}"'", "friendly_name": "Argon Fan Speed"}}'

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



action() {
  fanPercent=${1}
  fanLevel=${2}
  fanMode=${3}
  cpuTemp=${4}
  CorF=${5}
  fanPercentHex=$(printf '%x' "${fanPercent}")
  printf '%(%Y-%m-%d_%H:%M:%S)T'
  echo ": ${cpuTemp}${CorF} - Level ${fanLevel} - Fan ${fanPercent}% (${fanMode})";
  i2cset -y "${port}" "0x01a" "${fanPercentHex}"
  returnValue=${?}
  #Fan speed report on a new thread because it can be slow.
  test "${createEntity}" == "true" && fanSpeedReport "${fanPercent}" "${fanLevel}" "${fanMode}" "${cpuTemp}" "${CorF}" &
  return ${returnValue}
}

###
#Inputs - inputs from Home Assistant Config
###
CorF=$(jq -r '.CorF'<options.json)
t1=$(mkfloat "$(jq -r '.LowRange' <options.json)")
t2=$(mkfloat "$(jq -r '.MediumRange'<options.json)")
t3=$(mkfloat "$(jq -r '.HighRange'<options.json)")
quiet=$(jq -r '.QuietProfile'<options.json)
createEntity=$(jq -r '."Create a Fan Speed entity in Home Assistant"' <options.json)
logTemp=$(jq -r '."Log current temperature every 30 seconds"' <options.json)

###
#initial setup - prepare things for operation
###
fanLevel=-1;
previousFanLevel=-1;


thePort=255;

echo "Detecting Layout of i2c, we expect to see \"1a\" here."
calibrateI2CPort;
port=${thePort};
echo "I2C Port ${port}";

#Trap exits and set fan to 100% like a safe mode.
trap 'echo "Failed ${LINENO}: $BASH_COMMAND";i2cset -y ${port} 0x01a 0x63;previousFanLevel=-1;fanLevel=-1; echo Safe Mode Activated!;' ERR EXIT INT TERM


if [ "${port}" == 255 ]; then 
  echo "Argon One was not detected on i2c. Argon One will show a 1a on the i2c bus above. This add-on will not control temperature without a connection to Argon One.";
else 
  echo "Settings initialized. Argon One Detected. Beginning monitor.."
fi;

#Counts the number of repetitions so we can set a 10minute count. 
thirtySecondsCount=0;
#the current position, 0=unitialized. 1=off, 2=low, 3=medium, 4=high.
fanLevel=0;
#The name of the current position.
fanMode="off";
#The human readable percentage of the fan speed
fanPercent=0;

###
#Main Loop - read and react to changes in read temperature
###

until false; do
  read -r cpuRawTemp < /sys/class/thermal/thermal_zone0/temp #read instead of cat for process reduction
  cpuTemp=$(( cpuRawTemp/1000 )) #built-in bash math
  unit="C"

  if [ "$CorF" == "F" ]; then #convert to F
    cpuTemp=$(( ( cpuTemp *  9/5 ) + 32 ));
    unit="F"
  fi
  
  value=$(mkfloat $cpuTemp) #CPU Temp in floating point format.
  test "${logTemp}" == "true" && echo "Current Temperature $cpuTemp °$unit"

  #Choose a fan setting position by temperature comparison
  if ( fcomp "$value" '<=' "$t1" ); then
    fanLevel=1; #less than lowest
  elif ( fcomp "$t1" '<=' "$value" && fcomp "$value" '<=' "$t2" ); then
    fanLevel=2; #between 1 and 2
  elif ( fcomp "$t2" '<=' "$value" && fcomp "$value" '<=' "$t3" ); then
    fanLevel=3; #between 2 and 3
  else
    fanLevel=4;
  fi

  set +e

  if [ "${previousFanLevel}" != "${fanLevel}" ]; then
    #based on current position, and quiet mode, we can set the name and percentage of fanspeed.
    case $fanLevel in
      1)
          fanMode="OFF";
          fanPercent=0;
        ;;
      2)
        if [ "$quiet" != true ]; then
          fanMode="Low";
          fanPercent=33;
        else
          fanMode="Quiet Low";
          fanPercent=1;
        fi
        ;;
      3)
        if [ "$quiet" != true ]; then
          fanMode="Medium";
          fanPercent=66;
        else
          fanMode="Quiet Medium";
          fanPercent=3;
        fi
        ;;
      4)
        fanMode="High";
        fanPercent=100;
        ;;
    esac
    action "${fanPercent}" "${fanLevel}" "${fanMode}" "${cpuTemp}" "${CorF}";
    test $? -ne 0 && fanLevel=previousFanLevel
    previousFanLevel=$fanLevel
  fi
  
  test $((thirtySecondsCount%20)) == 0 && test "${createEntity}" == "true" && fanSpeedReport "${fanPercent}" "${fanLevel}" "${fanMode}" "${cpuTemp}" "${CorF}"
  sleep 30
  thirtySecondsCount=$((thirtySecondsCount + 1))
  #thirtySecondsCount mod 20 will be 0 once every 20 times, or approx. 10 minutes.
done
