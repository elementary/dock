# Dock

A quick app launcher and window switcher for Pantheon

## Building, Testing, and Installation

You'll need the following dependencies:

* libadwaita-1-dev
* libgtk-4-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja test` to build and run tests

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.elementary.dock`

    ninja install
    io.elementary.dock
