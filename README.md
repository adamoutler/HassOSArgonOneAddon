![image](gitResources/activecooling.jpg)

This is an addon for Argon One in Home Assistantan.  It's essentially a script that runs in a docker container.  It enables and automates the Argon One Active Cooling System with your specifications.<br>

# Installation
Within Home Assistant, click Supervisor-> Add-on Store -> … button (in top left)-> Repositories. Add this repository. 

Click ArgonOne Temp Control and install.<br>
![image](gitResources/addonSelect.png)

# Configuration
![image](gitResources/Configuration.png)
## Celcius or Farenheit
Choose Celcius or Farenheit.
* **CorF** - Configures Celcius or Fahrenheit.

## Temperature Ranges
![image](gitResources/FanRangeExplaination.png)

Set your fan ranges appropriately. 
* **LowRange** Minimum Temperature to turn oon 33%. Temperatures less than this value will turn the fan off.
* **MediumRange** to be the temperature divider between 33 and 66%.
* **HighRange** to be the maximum temperature before 100% fan.


# Enable I2C
In order to enable i2C, you must follow one of the methods below. 

## The easy way
https://community.home-assistant.io/t/add-on-hassos-i2c-configurator/264167

## The official way
https://www.home-assistant.io/hassio/enable_i2c/