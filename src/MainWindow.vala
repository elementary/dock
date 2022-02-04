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

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var empty_title = new Gtk.Label ("") {
            visible = false
        };

        child = box;
        overflow = Gtk.Overflow.VISIBLE;
        resizable = false;
        set_titlebar (empty_title);

        var settings = new Settings ("io.elementary.dock");

        foreach (string app_id in settings.get_strv ("launchers")) {
            box.append (new Launcher (app_id));
        }
    }
}
