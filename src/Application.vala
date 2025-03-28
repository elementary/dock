/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Application : Gtk.Application {
    public Application () {
        Object (application_id: "io.elementary.dock");
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();
        ShellKeyGrabber.init ();
        GalaDBus.init.begin ();

        unowned var granite_settings = Granite.Settings.get_default ();
        unowned var gtk_settings = Gtk.Settings.get_default ();

        granite_settings.notify["prefers-color-scheme"].connect (() =>
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK
        );

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK;
    }

    protected override void activate () {
        if (active_window == null) {
            var main_window = new MainWindow ();

            add_window (main_window);

            unowned var unity_client = Unity.get_default ();
            unity_client.add_client (AppSystem.get_default ());
        }

        active_window.present ();
    }

    public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
        base.dbus_register (connection, object_path);

        connection.register_object (object_path, new ItemInterface ());

        return true;
    }

    public static int main (string[] args) {
        return new Dock.Application ().run (args);
    }
}
