![image](gitResources/activecooling.jpg)

This Addon enables and activates automated active cooling.

# Installation

Within HA -  

1. Click Supervisor.
2. Click Add-on Store.
3. Click the … button (in top left).
4. Add [this](https://github.com/adamoutler/HassOSArgonOneAddon) Repository URL & [this](https://github.com/adamoutler/HassOSConfigurator) one too.
5. Press F5 to refresh your browser window.
6. Install 'HassOS I2C Configurator' from the Add-On store.
7. Once installed, browse to it in the Add-On store, then *turn off* "Protection Mode". Then click start.
8. Click the log tab, at the bottom you should see a final line that says `You will need to reboot twice total, once to place the files, and again to activate the I2C.` - If you see this, you are good to reboot the system...
9. Reboot No.1
10. Once the system is up again, *shutdown* - **full power off!!!**, then power back on.
11. One booted, click Supervisor -> Add-on Store.  
12. Open 'HassOS I2C Configurator', and then turn 'Protection Mode' back on.
13. Go back to the Add-on Store.
14. Install "ArgonOne XYZ", where XYZ is "Active Cooling", "Linear Cooling" or "Active Linear Cooling - Classic".  
![image](gitResources/addonSelect.png)  
15. Once installed, start the addon, and check the log. If you see `Settings initialized. Argon One Detected. Beginning monitor..` then you are good to begin configuration.

## Other I2C Notes
### The easy way

[Use the addon (what we used above)](https://community.home-assistant.io/t/add-on-hassos-i2c-configurator/264167)

### The official way

[Use the guide](https://www.home-assistant.io/hassio/enable_i2c/)


# Configuration

![image](gitResources/Configuration.png)

## Celsius or Fahrenheit

Choose Celsius or Fahrenheit.

- **Celsius or Fahrenheit** - Configures Celsius or Fahrenheit.

## Temperature Ranges

![image](gitResources/argonlinear.png)

Set your fan ranges appropriately.

- **Minimum Temperature** Lower temperatures will turn the fan off.
- **Maximum Temperature** The temperature at which the fan operates at 100%.
