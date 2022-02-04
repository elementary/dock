/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.Button {
    public string app_id { get; construct; }

    private static Gtk.CssProvider css_provider;

    public Launcher (string app_id) {
        Object (app_id: app_id);
    }

    class construct {
        set_css_name ("launcher");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/Launcher.css");
    }

    construct {
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var app_info = new GLib.DesktopAppInfo (app_id);

        var image = new Gtk.Image () {
            gicon = app_info.get_icon ()
        };
        image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        child = image;
        tooltip_text = app_info.get_display_name ();

        clicked.connect (() => {
            try {
                add_css_class ("bounce");
                app_info.launch (null, null);
            } catch (Error e) {
                critical (e.message);
            }
            Timeout.add (400, () => {
                remove_css_class ("bounce");

                return Source.REMOVE;
            });

        });
    }
}
