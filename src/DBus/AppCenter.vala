/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.appcenter")]
public interface AppCenterDBus : Object {
    public abstract async void install (string component_id) throws GLib.Error;
    public abstract async void update (string component_id) throws GLib.Error;
    public abstract async void uninstall (string component_id) throws GLib.Error;
    public abstract async string get_component_from_desktop_id (string desktop_id) throws GLib.Error;
    public abstract async string[] search_components (string query) throws GLib.Error;
}

public class Dock.AppCenter : Object {
    private const string DBUS_NAME = "io.elementary.appcenter";
    private const string DBUS_PATH = "/io/elementary/appcenter";
    private const uint RECONNECT_TIMEOUT = 5000U;

    private static AppCenter? instance;
    public static unowned AppCenter get_default () {
        if (instance == null) {
            instance = new AppCenter ();
        }

        return instance;
    }

    public AppCenterDBus? dbus { public get; private set; default = null; }

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.AUTO_START,
                        () => try_connect (), name_vanished_callback);
    }

    private AppCenter () {

    }

    private void try_connect () {
        Bus.get_proxy.begin<AppCenterDBus> (BusType.SESSION, DBUS_NAME, DBUS_PATH, 0, null, (obj, res) => {
            try {
                dbus = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning (e.message);
                Timeout.add (RECONNECT_TIMEOUT, () => {
                    try_connect ();
                    return false;
                });
            }
        });
    }

    private void name_vanished_callback (DBusConnection connection, string name) {
        dbus = null;
    }
}
