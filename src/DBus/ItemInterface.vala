/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.items")]
public class Dock.ItemInterface : Object {
    public void add_launcher (string app_id) throws DBusError, IOError {
        AppSystem.get_default ().add_app_for_id (app_id);
    }

    public void remove_launcher (string app_id) throws DBusError, IOError {
        AppSystem.get_default ().remove_app_by_id (app_id);
    }

    public string[] list_launchers () throws DBusError, IOError {
        return AppSystem.get_default ().list_launchers ();
    }
}
