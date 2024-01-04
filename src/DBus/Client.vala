/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.client")]
public class Dock.Client : Object {
    public void add_launcher (string app_id) throws DBusError, IOError {
        LauncherManager.get_default ().add_launcher_for_id (app_id);
    }

    public void remove_launcher (string app_id) throws DBusError, IOError {
        LauncherManager.get_default ().remove_launcher_by_id (app_id);
    }

    public string[] list_launchers () throws DBusError, IOError {
        return LauncherManager.get_default ().list_launchers ();
    }
}