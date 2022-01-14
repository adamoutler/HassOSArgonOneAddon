![image](https://raw.githubusercontent.com/adamoutler/HassOSArgonOneAddon/main/gitResources/activecooling.jpg)

This is an addon for Argon One in Home Assistant.
It's essentially a script that runs in a docker container.
It enables and automates the Argon One Active Cooling System with your specifications.

#ManageStyle is "Step":
This Addon keeps your temperature within specified ranges.
![image](https://raw.githubusercontent.com/adamoutler/HassOSArgonOneAddon/main/gitResources/FanRangeExplaination.png)

#ManageStyle is "Linear":
- 0 to 100 % speed fan is manage. 
- in "low range" put mini value temperature for 1% fan speed. 
- in "high range" put, maxi value temperature for 100% fan speed.

Mathematic formula applied:
    
    y = a*x + b
    y is fan speed
    x is instant temperature
    a is gradient 
    b is origin when y=0

    value_a=$((100/(tmaxi-tmini)))
    value_b=$((-value_a*tmini))
    fanPercent=$((value_a*value+value_b))



# Support
Need support? Click [here](https://community.home-assistant.io/t/argon-one-active-cooling-addon/262598/8).
Try to be detailed about your feedback.
If you can't be detailed, then please be as obnoxious as you can be.
