/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Application : Gtk.Application {
    private const OptionEntry[] OPTIONS = {
        { MainWindow.TOGGLE_APP_DRAWER_ACTION, 't', 0, OptionArg.NONE, null, "Toggle the app drawer" },
        { null }
    };

    construct {
        application_id = "io.elementary.dock";
        flags = HANDLES_COMMAND_LINE;

        add_main_option_entries (OPTIONS);
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();
        ShellKeyGrabber.init ();

        unowned var granite_settings = Granite.Settings.get_default ();
        unowned var gtk_settings = Gtk.Settings.get_default ();

        granite_settings.notify["prefers-color-scheme"].connect (() =>
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK
        );

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK;
    }

    protected override int command_line (ApplicationCommandLine command_line) {
        if (command_line.get_options_dict ().contains (MainWindow.TOGGLE_APP_DRAWER_ACTION)) {
            ((MainWindow) active_window).toggle_app_drawer ();
        }
        activate ();
        return 0;
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
