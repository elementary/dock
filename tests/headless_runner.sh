#!/bin/sh
xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" dbus-run-session "$1"
