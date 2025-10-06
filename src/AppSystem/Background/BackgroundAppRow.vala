/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundAppRow : Gtk.ListBoxRow {
    public BackgroundApp app { get; construct; }

    private Gtk.Stack button_stack;

    public BackgroundAppRow (BackgroundApp app) {
        Object (app: app);
    }

    construct {
        var icon = new Gtk.Image.from_gicon (app.app_info.get_icon ()) {
            icon_size = LARGE
        };

        var name = new Gtk.Label (app.app_info.get_display_name ()) {
            xalign = 0,
            hexpand = true
        };

        var message = new Gtk.Label (app.message) {
            xalign = 0,
            hexpand = true
        };
        message.add_css_class (Granite.CssClass.DIM);
        message.add_css_class (Granite.CssClass.SMALL);

        var button = new Gtk.Button.from_icon_name ("window-close-symbolic") {
            valign = CENTER,
            tooltip_text = _("Quit"),
        };
        button.add_css_class ("close-button");
        button.add_css_class (Granite.CssClass.CIRCULAR);
        button.add_css_class (Granite.CssClass.DESTRUCTIVE);

        var spinner = new Gtk.Spinner () {
            spinning = true
        };

        button_stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        button_stack.add_named (button, "button");
        button_stack.add_named (spinner, "spinner");

        var grid = new Gtk.Grid () {
            column_spacing = 9,
            row_spacing = 3
        };
        grid.attach (icon, 0, 0, 1, 2);

        if (app.message != null) {
            grid.attach (name, 1, 0);
            grid.attach (message, 1, 1);
        } else {
            grid.attach (name, 1, 0, 1, 2);
        }

        grid.attach (button_stack, 2, 0, 1, 2);

        child = grid;

        button.clicked.connect (on_button_clicked);
    }

    private async void on_button_clicked () {
        button_stack.set_visible_child_name ("spinner");

        try {
            yield app.kill ();
        } catch (Error e) {
            button_stack.set_visible_child_name ("button");

            var failed_notification = new GLib.Notification (
                "Failed to end app %s".printf (app.app_info.get_display_name ())
            );
            GLib.Application.get_default ().send_notification (null, failed_notification);

            return;
        }

        Timeout.add_seconds (5, () => {
            // Assume killing failed
            button_stack.set_visible_child_name ("button");
            return Source.REMOVE;
        });
    }
}
