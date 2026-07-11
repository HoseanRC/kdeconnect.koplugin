# KDE Connect plugin for koreader

## Installation

1. **Download** the ZIP file from the latest release on the [Releases Page](https://github.com/HoseanRC/kdeconnect.koplugin/releases).
2. **Extract** the ZIP archive.
3. **Move** the kdeconnect.koplugin directory into the koreader/plugins/ directory on your device.
4. **Restart** koreader or the whole device.

## Usage

1. Connect both your e-book and the device you want to connect (eg. your phone, your computer, your laptop) **to the same network**
2. **Open** KDE Connect on your device and **refresh**
3. Tap on your e-book shown in the app and press "**Request pairing**"
4. Press "**Pair**" on your e-book
5. **Enjoy**

## What exactly is this?

KDE Connect is a simple app that's installed on any computer or phone you got in your home or office and it will connect everything to each other

The premise is simple. Create a seamless ecosystem with 0 hassle (and keep it opensource)

You might have seen this in Apple devices where everything on the same account are in a way all connected to each other (while Apple implements it on their own chips, KDE Connect works on any regular WiFi)

## But why on e-book?

**Why not?**

We're talking about a whole ecosystem where everything can control each other and transfer data with a click of a button.

Having everything an ecosystem requires in a single plugin makes it much easier to:

- Copy a text on a device and use it on another
- Share a file between the devices
- Get your phone notifications while you're reading

## How?

the project splits into 2 parts

1. **LUA**: for almost everything.
   1. **Discovery**
   2. **Pairing**
   3. **Connection**
   4. **Encryption**
   5. **Plugins**
2. **Native**: where the only native code is used to secure the protocol

   the code is written in **C** and requires **WolfSSL** library to generate the Private key and Certificate

   these are used by KDE Connect to identify each device and secure the connection between the devices

[KDE Connect protocol specification](https://github.com/KDE/kdeconnect-meta/blob/master/protocol.md)

## What about Calibre?

It's clear how **Calibre** nails book syncing and it's in many cases better to be used than **KDE Connect** (which can't sync book progress)

however, **KDE Connect** is not designed for e-books. It's designed for an ecosystem!

You can use **Calibre** standalone and get full book sync  
You can use **KDE Connect** standalone and send your books (PDFs or EPUBs) and use its other functionalities  
You can also use both **at the same time**

Both projects are different and have their own uses, but they do not contredict each other, so there are no problem in mixing the two.

## what works?

What works are currently:

1. **Pairing**
2. **Pinging**
3. **Notification Sync**
4. **Clipboard Sync**

**File sharing is WIP, but other plugins are not planned**

> [!IMPORTANT]
> this plugin is designed to work on all devices with **ARMv7** or above architecture.  
> if your device can't run the plugin, **please report it**.
