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
  echo $str;
}

## Float comparison so that we don't need to call non-bash processes
fcomp() {
    local oldIFS="$IFS" op=$2 x y digitx digity
    IFS='.' x=( ${1##+([0]|[-]|[+])}) y=( ${3##+([0]|[-]|[+])}) IFS="$oldIFS"
    while [[ "${x[1]}${y[1]}" =~ [^0] ]]; do
        digitx=${x[1]:0:1} digity=${y[1]:0:1}
        (( x[0] = x[0] * 10 + ${digitx:-0} , y[0] = y[0] * 10 + ${digity:-0} ))
        x[1]=${x[1]:1} y[1]=${y[1]:1} 
    done
    [[ ${1:0:1} == '-' ]] && (( x[0] *= -1 ))
    [[ ${3:0:1} == '-' ]] && (( y[0] *= -1 ))
    (( ${x:-0} $op ${y:-0} ))
} 


fanSpeedReport(){
   percent=$1;
   level=$2;
   mode=$3;
   case $level in
      1)
        icon=mdi:fan-off;
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
        icon=mdi:fan-off;
    esac
    reqBody='{"state": "'${percent}'", "attributes": { "unit_of_measurement": "%", "icon": "'${icon}'", "mode": "'${mode}'", "fan level": "'${level}'", "friendly_name": "Argon Fan Speed"}}'
    nc -i 1 hassio 80 1>/dev/null <<<unix2dos<<EOF
POST /homeassistant/api/states/sensor.argon_one_addon_fan_speed HTTP/1.1
Authorization: Bearer ${SUPERVISOR_TOKEN}
Content-Length: $( echo -ne ${reqBody} | wc -c ) 

${reqBody}
EOF
};



action() {
  level=${1}
  percent=${2}
  name=${3}
  percentHex=${4}
  echo "Level $level - Fan $percent% ($name)";
  test ${createEntity} == "true" && fanSpeedReport $percent $level $name  
  i2cset -y 1 0x01a ${percentHex}
  return ${?}
}




###
#Inputs - inputs from Home Assistant Config
###
CorF=$(cat options.json |jq -r '.CorF')
t1=$(mkfloat $(cat options.json |jq -r '.LowRange'))
t2=$(mkfloat $(cat options.json |jq -r '.MediumRange'))
t3=$(mkfloat $(cat options.json |jq -r '.HighRange'))
quiet=$(cat options.json |jq -r '.QuietProfile')
createEntity=$(cat options.json |jq -r '."Create a Fan Speed entity in Home Assistant"')


###
#initial setup - prepare things for operation
###
curPosition=-1;
lastPosition=-1;
trap 'i2cset -y 1 0x01a 0x00' EXIT INT TERM

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





###
#Main Loop - read and react to changes in read temperature
###
until false; do
  read cpuRawTemp</sys/class/thermal/thermal_zone0/temp #read instead of cat fpr process reduction
  cpuTemp=$(( $cpuRawTemp/1000 )) #built-in bash math
    unit="C"
  if [ $CorF == "F" ]; then #convert to F
    cpuTemp=$(( ( $cpuTemp *  9/5 ) + 32 ));
    unit="F"
  fi
  value=$(mkfloat $cpuTemp)
  echo "Current Temperature $cpuTemp °$unit"

  #Choose a fan setting position by temperature comparison
  if ( fcomp $value '<=' $t1 ); then
    curPosition=1; #less than lowest
  elif ( fcomp $t1 '<=' $value && fcomp $value '<=' $t2 ); then
    curPosition=2; #between 1 and 2
  elif ( fcomp $t2 '<=' $value && fcomp $value '<=' $t3 ); then
    curPosition=3; #between 2 and 3
  else
    curPosition=4;
  fi
  if [ $lastPosition != $curPosition ]; then
    set +e

    #convert fan position to a level and activate fan
    case $curPosition in
      1)
         action 1 0 "OFF" 0x00
         test $? -ne 0 && curPosition=lastPosition;
      ;;
      2)
        if [ $quiet != true ]; then
          action 2 33 "Low" 0x0a
          test $? -ne 0 && curPosition=lastPosition;
        else
          action 2 1 "Quiet Low" 0x01
          test $? -ne 0 && curPosition=lastPosition;
        fi
        ;;
      3)
        if [ $quiet != true ]; then
          action 3 66 "Medium" 0x042
          test $? -ne 0 && curPosition=lastPosition;
        else
          action 3 3 "Quiet Medium" 0x03
          test $? -ne 0 && curPosition=lastPosition;
        fi
        ;;
      *)
        action 4 100 "High" 0x64
        test $? -ne 0 && curPosition=lastPosition;
        ;;
    esac
    set -e
    lastPosition=$curPosition;
  fi
  sleep 30;
done
