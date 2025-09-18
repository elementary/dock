/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.items")]
public class Dock.ItemInterface : Object {
    public void add_launcher (string app_id) throws DBusError, IOError {
        var settings = new Settings ("io.elementary.dock");
        settings.set_strv ("launchers", settings.get_strv ("launchers") + app_id);
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
