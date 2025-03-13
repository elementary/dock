/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.ApplicationButton : Gtk.FlowBoxChild {
    private static GLib.Settings dock_settings;

    static construct {
        dock_settings = new GLib.Settings ("io.elementary.dock");
    }

    public App app { get; construct; }

    private Gtk.Image image;

    public ApplicationButton (App app) {
        Object (app: app);
    }

    construct {
        image = new Gtk.Image.from_gicon (app.app_info.get_icon ());
        dock_settings.bind ("icon-size", image, "pixel-size", GET);

        var label = new Gtk.Label (app.app_info.get_display_name ()) {
            wrap = true,
            ellipsize = END,
        };

        var box = new Gtk.Box (VERTICAL, 6);
        box.append (image);
        box.append (label);

        var button = new Gtk.Button () {
            child = box
        };
        button.add_css_class (Granite.STYLE_CLASS_FLAT);

        child = button;

        button.clicked.connect (on_clicked);
    }

    private void on_clicked () {
        var popover = (Gtk.Popover) get_ancestor (typeof (Gtk.Popover));
        popover.popdown ();

        app.launch (Gdk.Display.get_default ().get_app_launch_context ());
    }
}
