/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.items")]
public class Dock.ItemInterface : Object {
    [DBus (visible = false)]
    public AppSystem app_system { private get; construct; }

    [DBus (visible = false)]
    public ItemInterface (AppSystem app_system) {
        Object (app_system: app_system);
    }

    public void add_launcher (string app_id) throws DBusError, IOError {
        app_system.add_app_for_id (app_id);
    }

    public void remove_launcher (string app_id) throws DBusError, IOError {
        app_system.remove_app_by_id (app_id);
    }

    public string[] list_launchers () throws DBusError, IOError {
        return app_system.list_launchers ();
    }
}
