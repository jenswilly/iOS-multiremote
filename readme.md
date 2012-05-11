# Bluetooth LE Multi-remote project readme

This is the iOS app source code for the Bluetooth LE enabled multi-remote controller project. Read more about the project (including schematics and board layouts) here: [http://atomslagstyrken.dk/arduino/tag/remotecontrol/](http://atomslagstyrken.dk/arduino/tag/remotecontrol/).

## Comments

### 2012-05-09
The first version is working! Yay!

### 2012-05-11
- Updated interface a bit.
- The app now attempts to connect automatically when becoming active. Command buttons are first enabled when a device is connected.
- The command buttons now send S-00<button number> where <button number> is from 1 to 4.
- Learning is done by first pressing the "Record" button and then the command button to be learned. This sends L-00<number> to the device. (Now I just need both the BLE and MCU to listen for and pass on the button number. And the MCU to be able to store more than one command. And both.)
