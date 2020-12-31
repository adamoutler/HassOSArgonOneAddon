#!/usr/bin/with-contenv bashio
CorF=$(cat options.json |jq -r '.CorF')

x1=$(cat options.json |jq -r '.LowRange')
x2=$(cat options.json |jq -r '.MediumRange')
x3=$(cat options.json |jq -r '.HighRange')
lastPosition=0
curPosition=-1

trap 'i2cset -y 1 0x01a 0x00' EXIT INT TERM


until false; do
  cpuTemp=$(( $(cat /sys/class/thermal/thermal_zone0/temp ) / 1000  ))
  unit="C"
  if [ $CorF == "F" ]; then
    cpuTemp=$(( ( $cpuTemp *  9/5 ) + 32 ));
    unit="F"
  fi
  value=$cpuTemp
  echo "Current Temperature $cpuTemp °$unit"
  if (( $( bc <<<"$value <= $x1" ) )); then
    curPosition=1; #less than lowest
  elif (( $( bc <<<"$x1 <= $value && $value <= $x2" ) )); then
    curPosition=2; #between 1 and 2
  elif (( $( bc <<<"$x2 <= $value && $value <= $x3" ) )); then
    curPosition=3; #between 2 and 3
  else
    curPosition=4;
  fi
  if [ $lastPosition != $curPosition ]; then
   echo last level: $lastPosition current level: $curPosition;
   case $curPosition in
    1)
     echo level 1;
     i2cset -y 1 0x01a 0x00
     ;;
    2)
     echo level 2;
     i2cset -y 1 0x01a 0x21
     ;;
    3)
     echo level 3;
     i2cset -y 1 0x01a 0x42
     ;;
    *)
     echo level4;
     i2cset -y 1 0x01a 0x64
     ;;
   esac
   lastPosition=$curPosition;
  fi
  sleep 30;
done
