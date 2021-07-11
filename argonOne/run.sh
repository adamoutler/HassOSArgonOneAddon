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
   percent=${1};
   level=${2};
   mode=${3};
   temp=${4};
   CorF=${5};
   case ${level} in
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
    reqBody='{"state": "'"${percent}"'", "attributes": { "unit_of_measurement": "%", "icon": "'"${icon}"'", "mode": "'"${mode}"'", "Temperature '"${CorF}"'": "'"${temp}"'", "fan level": "'"${level}"'", "friendly_name": "Argon Fan Speed"}}'
    nc -i 1 hassio 80 1>/dev/null <<<unix2dos<<EOF
POST /homeassistant/api/states/sensor.argon_one_addon_fan_speed HTTP/1.1
Authorization: Bearer ${SUPERVISOR_TOKEN}
Content-Length: $( echo -ne "${reqBody}" | wc -c )

${reqBody}
EOF
};



action() {
  level=${1}
  percent=${2}
  name=${3}
  percentHex=${4}
  temp=${5}
  CorF=${6}
  printf '%(%Y-%m-%d_%H:%M:%S)T'
  echo ": ${temp}${CorF} - Level ${level} - Fan ${percent}% (${name})";
  i2cset -y 1 0x01a "${percentHex}"
  returnValue=${?}
  test "${createEntity}" == "true" && fanSpeedReport "${percent}" "${level}" "${name}" "${temp}" "${CorF}" &
  return ${returnValue}
}

###
#Inputs - inputs from Home Assistant Config
###
CorF=$(jq -r '.CorF'<options.json)
t1=$(mkfloat $(jq -r '.LowRange' <options.json))
t2=$(mkfloat $(jq -r '.MediumRange'<options.json))
t3=$(mkfloat $(jq -r '.HighRange'<options.json))
quiet=$(jq -r '.QuietProfile'<options.json)
createEntity=$(jq -r '."Create a Fan Speed entity in Home Assistant"' <options.json)
logTemp=$(jq -r '."Log current temperature every 30 seconds"' <options.json)

###
#initial setup - prepare things for operation
###
curPosition=-1;
lastPosition=-1;

#Trap exits and set fan to 100% like a safe mode.
trap 'echo "Failed ${LINENO}: $BASH_COMMAND";i2cset -y 1 0x01a 0x63;lastPosition=-1;curPosition=-1; echo Safe Mode Activated!;' ERR EXIT INT TERM

if [ ! -e /dev/i2c-1 ]; then
  echo "Cannot find I2C port.  You must enable I2C for this add-on to operate properly";
  exit 1;
fi

echo "Detecting Layout of i2c, we expect to see \"1a\" here."
i2cDetect=$(i2cdetect -y -a 1);
echo -e "${i2cDetect}"

if [[ "$i2cDetect" != *"1a"* ]]; then 
  echo "Argon One was not detected on i2c. Argon One will show a 1a on the i2c bus above. This add-on will not control temperature without a connection to Argon One.";
else 
  echo "Settings initialized. Argon One Detected. Beginning monitor.."
fi;

#Counts the number of repetitions so we can set a 10minute count. 
thirtySecondsCount=0;
#the current position, 0=unitialized. 1=off, 2=low, 3=medium, 4=high.
curPosition=0;
#The name of the current position.
curPositionName="off";
#The human readable percentage of the fan speed
fanPercent=0;

###
#Main Loop - read and react to changes in read temperature
###

until false; do
  read -r cpuRawTemp</sys/class/thermal/thermal_zone0/temp #read instead of cat fpr process reduction
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
    curPosition=1; #less than lowest
  elif ( fcomp "$t1" '<=' "$value" && fcomp "$value" '<=' "$t2" ); then
    curPosition=2; #between 1 and 2
  elif ( fcomp "$t2" '<=' "$value" && fcomp "$value" '<=' "$t3" ); then
    curPosition=3; #between 2 and 3
  else
    curPosition=4;
  fi
  set +e
  if [ $lastPosition != $curPosition ]; then
    #based on current position, and quiet mode, we can set the name and percentage of fanspeed.
    case $curPosition in
      1)
          curPosition=1;
          curPositionName="OFF";
          fanPercent=0;
        ;;
      2)
        curPosition=2;
        if [ "$quiet" != true ]; then
          curPositionName="Low";
          fanPercent=33;
        else
          curPositionName="Quiet Low";
          fanPercent=1;
        fi
        ;;
      3)
        curPosition=3;
        if [ "$quiet" != true ]; then
          curPositionName="Medium";
          fanPercent=66;
        else
          curPositionName="Quiet Medium";
          fanPercent=3;
        fi
        ;;
      *)
        curPosition=4;
        curPositionName="High";
        fanPercent=100;
        ;;
    esac
    fanPercentHex=$(printf '%x' ${fanPercent})
    action "${curPosition}" "${fanPercent}" "${curPositionName}" "${fanPercentHex}" "${cpuTemp}" "${CorF}"
    test $? -ne 0 && curPosition=lastPosition;
    lastPosition=$curPosition;
  fi
  sleep 30;
  thirtySecondsCount=$((thirtySecondsCount + 1))
  #thirtySecondsCount mod 20 will be 0 once every 20 times, or approx. 10 minutes.
  test $((thirtySecondsCount%20)) == 0 && test "${createEntity}" == "true" && fanSpeedReport "${percent}" "${level}" "${name}" "${cpuTemp}" "${CorF}"
done
