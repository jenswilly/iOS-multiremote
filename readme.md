# Bluetooth LE Multi-remote project readme

This is the iOS app source code for the Bluetooth LE enabled multi-remote controller project. Read more about the project (including schematics and board layouts) here: [http://atomslagstyrken.dk/arduino/tag/remotecontrol/](http://atomslagstyrken.dk/arduino/tag/remotecontrol/).

## To-do

- XML file parser for an _iTunes File Sharing_ document specifying the button layout.  
Layout should be in defined in pages and either rows/columns or coordinates and button specification should be something like button color, text or image (choose between available or add own).
- Maybe supress "device disconnected" warnings if possible?

## Progress

### 2012-05-12
- New icon: ![Icon](https://github.com/jenswilly/iOS-multiremote/blob/master/Resources/App%20Icon%20%5BSquared%5D/Icon.png?raw=true)

### 2012-05-11
- Updated interface a bit.
- The app now attempts to connect automatically when becoming active. Command buttons are first enabled when a device is connected.
- The command buttons now send S-00[1-4].
- Learning is done by first pressing the "Record" button and then the command button to be learned. This sends L-00[1-4] to the device. (Now I just need both the BLE and MCU to listen for and pass on the button number. And the MCU to be able to store more than one command. And both.)

### 2012-05-09
The first version is working! Yay!

### 2012-06-07
Began converting to universal app.