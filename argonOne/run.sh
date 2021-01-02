#!/usr/bin/with-contenv bashio


# #make everything into a float
mkfloat(){
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

CorF=$(cat options.json |jq -r '.CorF')
t1=$(mkfloat $(cat options.json |jq -r '.LowRange'))
t2=$(mkfloat $(cat options.json |jq -r '.MediumRange'))
t3=$(mkfloat $(cat options.json |jq -r '.HighRange'))
lastPosition=0
curPosition=-1

trap 'i2cset -y 1 0x01a 0x00' EXIT INT TERM

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
   echo last level: $lastPosition current level: $curPosition;
   case $curPosition in
    1)
     echo "Level 1 - Fan 0% (OFF)";
     i2cset -y 1 0x01a 0x00
     ;;
    2)
     echo "Level 2 - Fan 33% (Low)";
     i2cset -y 1 0x01a 0x21
     ;;
    3)
     echo "Level 3 - Fan 66% (Medium)";
     i2cset -y 1 0x01a 0x42
     ;;
    *)
     echo "Level4 - Fan 100% (High)";
     i2cset -y 1 0x01a 0x64
     ;;
   esac
   lastPosition=$curPosition;
  fi
  sleep 30;
done
