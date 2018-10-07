# DENON
## DENON AVR plugin for VERA

### What does it do
Controls DENON AVR using the Denon telnet protocol
tested on : AVR4311 and X3400H models


### Functionality
Provides a plugin for VERA to enable control of PowerON / Standby , Mute On Off , and more generally sending a sequence of telnet commands

### Variables
Debug: 1 to set the debug mode for the plugin
LastResult: a csv separated string containing the sequence of responses received from the AVR after sending a command
Status: 1 for powered on status,  0 for powered off status - readonly variable
Version: version of the plugin

### UPNP Actions
SetDebug(newDebugMode) : set or unset the debug mode of the plugin ( extra verbosity in vera's log )
SendCmd(newCmd) : cmd is a csv separated string of one or several commands to send to the AVR. for instance "PW?,SI?"
PowerOn : to poweron the AVR
StandBy : to put the AVR in standby mode
Mute( MuteOn ) :  1 to mute the AVR,  0 to unmute

### Triggers
none

### Future evolutions and architectural flexibility
n/a

### Installation
download the files and upload them into the VERA develop apps / luup files page
select Restart Luup after load
once reloaded, set the ip address of the AVR in the setting pages or in the device attributes page
( static IP configuration for the AVR is necessary recommanded ) 