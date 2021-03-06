# DENON
## DENON AVR plugin for VERA

### What does it do
Controls DENON AVR using the Denon telnet protocol
tested on : AVR4311 and X3400H models

### Functionality
Provides a plugin for VERA to enable control of PowerON / Standby , Mute On Off , and more generally sending a sequence of telnet commands
you can select the source input by using sendCmd("SITV") command for instance. SI commands are defined in Denon telnet protocol documentation. ALTUI offers an easy interface to select them from the ALTUI UI.

To program actions in scenes, you use the UPNP commands in the advanced scene editor of UI7 or ALTUI.

### Cost
Freeware but Donations are appreciated : 
https://www.paypal.com/donate/?token=sHd22BzsIP7WQDQwkkUgvfx_wNbhvxc-zzkOKh-afkzEc5xHAXPOa7sTsbpy-2tfDCoGvm&country.x=FR&locale.x=FR

### Versions
* v0.4 : fully functional, SendCmd() to send any command. PowerOn, StandBy and Mute UPNP as helpers. ALTUI integration

### UI
* Control page in UI7
![ALTUI image](https://raw.githubusercontent.com/amg0/Denon/master/Doc/Control.PNG)

### Variables
* Debug: 1 to set the debug mode for the plugin
* LastResult: a csv separated string containing the sequence of responses received from the AVR after sending a command
* Status: 1 for powered on status,  0 for powered off status - readonly variable
* Version: version of the plugin

### UPNP Actions
* SetDebug(newDebugMode) : set or unset the debug mode of the plugin ( extra verbosity in vera's log )
* SendCmd(newCmd) : cmd is a csv separated string of one or several commands to send to the AVR. for instance "PW?,SI?"
* PowerOn : to poweron the AVR
* StandBy : to put the AVR in standby mode
* Mute( MuteOn ) :  1 to mute the AVR,  0 to unmute

### Triggers
none

### Misc Notes
Denon AVR only support one telnet connection at a time, so to make it work it is important that you insure no other app is using the AVR telnet protocol at the same time.
By design, this plugin connects and disconnect from the AVR for each commands, therefore it does not keep the connection open and should limit the problem.
One drawback is that you should not call 2 SendCmd() one after the other too fast. spacing of 1 sec is recommanded. 
in order to overcome this limitation sendCmd() supports sending several chained commands if you separate them with a comma (,)

* Special support for ALTUI display

The Icon of the device will be green or red depending if the network connectivity was successful or not. ( meaning the device is switched on and connected on the network ). 
NOTE that this is not poweron / standby status. so if the icon is red the device is not present or ipaddr is not correct. if the icon is green, the device maybe either
in power on or standby mode.  The color of the standby / power button will reflect the current state.

![ALTUI image](https://raw.githubusercontent.com/amg0/Denon/master/Doc/Denon.PNG)

### Installation
download the files and upload them into the VERA develop apps / luup files page
select Restart Luup after load
once reloaded, set the ip address of the AVR in the setting pages or in the device attributes page
( static IP configuration for the AVR is necessary recommanded ) 