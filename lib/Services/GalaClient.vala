/*
 *  Copyright (C) 2020
 *
 *  This file is part of Plank.
 *
 *  Plank is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Plank is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


[DBus (name = "org.pantheon.gala")]
public interface INotifyPlugin : Object {
    public abstract void show_preview () throws Error;
    public abstract void hide_preview () throws Error;
}

public class Plank.Services.GalaClient : Object {
    private INotifyPlugin? bus;

    private const string DBUS_NAME = "org.pantheon.gala";
    private const string DBUS_PATH = "/org/pantheon/gala";

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE,
                () => connect_dbus (),
                () => bus = null);
    }

    public void show_preview () {
        debug("show preview!");
        if (bus != null) {
            try {
                bus.show_preview ();
            } catch (Error e) {
                warning (e.message);
            }
        }
    }

    public void hide_preview () {
        debug("hide preview!");
        if (bus != null) {
            try {
                bus.hide_preview ();
            } catch (Error e) {
                warning (e.message);
            }
        }
    }

    private void connect_dbus () {
        try {
            bus = Bus.get_proxy_sync (BusType.SESSION, DBUS_NAME, DBUS_PATH);
        } catch (Error e) {
            warning ("Connecting to \"%s\" failed: %s", DBUS_NAME, e.message);
        }
    }
}
