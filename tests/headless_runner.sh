#!/bin/sh
mkdir -p /run/dbus
mkdir -p /var
ln -s /var/run /run

dbus-daemon --system --fork

$1
