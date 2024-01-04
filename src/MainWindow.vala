/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    private static Gtk.CssProvider css_provider;

    class construct {
        set_css_name ("dock");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/MainWindow.css");
    }

    construct {
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var launcher_manager = LauncherManager.get_default ();

        var empty_title = new Gtk.Label ("") {
            visible = false
        };

        child = launcher_manager;
        overflow = Gtk.Overflow.VISIBLE;
        resizable = false;
        set_titlebar (empty_title);

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        launcher_manager.add_controller (drop_target_launcher);
    }
}
