# Plank

Plank is meant to be the simplest dock on the planet. The goal is to provide
just what a dock needs and absolutely nothing more. It is, however, a library
which can be extended to create other dock programs with more advanced features.

(Codenames for releases are currently based on characters of "Ed, Edd n Eddy".)

# Reporting Bugs

You can report bugs here: https://bugs.launchpad.net/plank
Please try and avoid making duplicate bugs - search for existing bugs before
reporting a new bug!
You also might want to jump on our IRC channel (see below)


# Where Can I Get Help?

IRC: #plank on FreeNode - irc://irc.freenode.net/#plank
Common problems and solutions
https://answers.launchpad.net/plank


# How Can I Get Involved?

Visit the Launchpad page: https://launchpad.net/plank
Help translate: https://translations.launchpad.net/plank
Answer questions: https://answers.launchpad.net/plank


# Are there online API documentations?

http://people.ubuntu.com/~ricotz/docs/vala-doc/plank/index.htm

## Building, Testing, and Installation

You'll need the following dependencies:
* at-spi2-core dbus-x11 gnome-common libbamf3-dev libcairo2-dev libdbusmenu-gtk3-dev libgdk-pixbuf2.0-dev libgee-0.8-dev libglib2.0-dev libgnome-menu-3-dev libgtk-3-dev libwnck-3-dev libx11-dev libxml2-utils meson valac xvfb

Run `meson` to configure the build environment and then `ninja test` to build and run tests

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `plank`

    ninja install
    plank



