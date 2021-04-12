![image](gitResources/activecooling.jpg)

This is an addon for Argon One in Home Assistantant activating and enabling automatic active cooling.

# Installation

Within HA, click Supervisor-> Add-on Store -> … button (in top left)-> Repositories and add this URL.

Click ArgonOne Temp Control and install.<br>
![image](gitResources/addonSelect.png)

# Configuration

![image](gitResources/Configuration.png)

## Celcius or Farenheit

Choose Celcius or Farenheit.

- **CorF** - Configures Celcius or Fahrenheit.

## Temperature Ranges

![image](gitResources/FanRangeExplaination.png)

Set your fan ranges appropriately.

- **LowRange** Minimum Temperature to turn oon 33%. Lower will turn the fan off.
- **MediumRange** to be the temperature divider between 33 and 66%.
- **HighRange** to be the maximum temperature before 100% fan.

# Enable I2C

In order to enable i2C, you must follow one of the methods below.

## The easy way

https://community.home-assistant.io/t/add-on-hassos-i2c-configurator/264167

## The official way

https://www.home-assistant.io/hassio/enable_i2c/
