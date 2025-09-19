/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.items")]
public class Dock.ItemInterface : Object {
    private static GLib.Once<ItemInterface> instance;
    public static unowned ItemInterface get_default () {
        return instance.once (() => { return new ItemInterface (); });
    }

    private ItemInterface () {}

    public void add_launcher (string app_id) throws DBusError, IOError {
        var settings = new Settings ("io.elementary.dock");

        var new_launchers = settings.get_strv ("launchers");
        new_launchers += app_id;

        settings.set_strv ("launchers", new_launchers);
    }

    public void remove_launcher (string app_id) throws DBusError, IOError {
        var settings = new Settings ("io.elementary.dock");

        string[] new_keys = {};
        foreach (unowned var launcher in settings.get_strv ("launchers")) {
            if (launcher != app_id) {
                new_keys += launcher;
            }
        }

        settings.set_strv ("launchers", new_keys);
    }

    public string[] list_launchers () throws DBusError, IOError {
        return new Settings ("io.elementary.dock").get_strv ("launchers");
    }
}
