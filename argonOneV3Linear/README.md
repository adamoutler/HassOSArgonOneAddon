# Active Linear Cooling

![image](https://raw.githubusercontent.com/adamoutler/HassOSArgonOneAddon/main/gitResources/activecooling.jpg)

This is an addon for Argon One V3 in Home Assistant.
It's essentially a script that runs in a docker container.
It enables and automates the Argon One V3 Active Cooling System with your specifications.
It smoothly increases the fan speed based on the temperature.

This Addon keeps your temperature within specified ranges.

![image](https://raw.githubusercontent.com/adamoutler/HassOSArgonOneAddon/main/gitResources/argonlinear.png)

- The addon manages fan speed from 0 to 100%
- Configure "Minimum temperature" to set the 1% speed.
- Configure "Maximum temperature" to set the 100% speed.
- The fan will be off until the minimum temperature is reached.

Mathematic formula applied:

```y = a*x + b
y is fan speed
x is instant temperature
a is gradient
b is origin when y=0

value_a=$((100/(tmaxi-tmini)))
value_b=$((-value_a*tmini))
fanPercent=$((value_a*value+value_b))
```

## Support

First, look in the Logs tab of the Addon's page in HA to see if i2c was set up properly,
 or for any other errors.

Also, enable the "Log current temperature every 30 seconds" setting and look in the
 logs to see what the speed is. The fan is noisy and you might not be able to hear
 different speeds, but logging will verify any changes.

Need support? Click [here](https://community.home-assistant.io/t/argon-one-active-cooling-addon/262598/8).
Try to be detailed about your feedback.
If you can't be detailed, then please be as obnoxious as you can be.
