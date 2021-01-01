# Raspberry Pi Temp Monitor
This provides a temperature sensor for the Raspberry Pi processor

# Configuration
![image](gitResources\Configuration.png)
## Celcius or Farenheit
Choose Celcius or Farenheit.
* **CorF** - Configures Celcius or Fahrenheit.

## Temperature Ranges
![image](gitResources\FanRangeExplaination.png)

Set your fan ranges appropriately. 
* **LowRange** Minimum Temperature to turn oon 33%. Temperatures less than this value will turn the fan off.
* **MediumRange** to be the temperature divider between 33 and 66%.
* **HighRange** to be the maximum temperature before 100% fan.

# Info
You must disable Protection mode.  This add-on works directly with the hardware so it requires Protection Mode to be disabled to access the appropriate hardware devices. <br>
![image](gitResources\protectionMode.png)

# Enable I2C
In order to enable i2C, you must follow the directions in this link. 
https://www.home-assistant.io/hassio/enable_i2c/