/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Application : Gtk.Application {
    private const string LAUNCH_INDEX = "launch-index";

    private const OptionEntry[] OPTIONS = {
        { LAUNCH_INDEX, 'i', OptionFlags.NONE, OptionArg.INT, null, "Launch the app that's currently at the given index. Should only be used if dock is already running", "INT" },
    };

    public Application () {
        Object (
            application_id: "io.elementary.dock",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
    }

    construct {
        add_main_option_entries (OPTIONS);
    }

    protected override void startup () {
        base.startup ();

        Granite.init ();

        unowned var granite_settings = Granite.Settings.get_default ();
        unowned var gtk_settings = Gtk.Settings.get_default ();

        granite_settings.notify["prefers-color-scheme"].connect (() =>
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK
        );

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == DARK;
    }

    protected override int command_line (ApplicationCommandLine command_line) {
        var options = command_line.get_options_dict ();

        if (LAUNCH_INDEX in options) {
            // Cast to int to automatically get the int from the variant and then to uint for our index
            // I like how this looks so I left it instead of something more expressive like get_int32 :P
            LauncherManager.get_default ().launch ((uint)(int) options.lookup_value (LAUNCH_INDEX, VariantType.INT32));
        } else {
            activate ();
        }

        return 0;
    }

    protected override void activate () {
        if (active_window == null) {
            var main_window = new MainWindow ();

            add_window (main_window);

            unowned var unity_client = Unity.get_default ();
            unity_client.add_client (LauncherManager.get_default ());
        }

        active_window.present_with_time (Gdk.CURRENT_TIME);
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
