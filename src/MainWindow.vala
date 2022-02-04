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

        var files_launcher = new Launcher ("io.elementary.files.desktop");
        var web_launcher = new Launcher ("org.gnome.Epiphany.desktop");
        var music_launcher = new Launcher ("io.elementary.music.desktop");
        var mail_launcher = new Launcher ("io.elementary.mail.desktop");

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box.append (files_launcher);
        box.append (web_launcher);
        box.append (mail_launcher);
        box.append (music_launcher);

        var empty_title = new Gtk.Label ("") {
            visible = false
        };

        child = box;
        resizable = false;
        set_titlebar (empty_title);
    }
}
