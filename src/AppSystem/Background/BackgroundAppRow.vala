/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundAppRow : Gtk.ListBoxRow {
    public BackgroundApp app { get; construct; }

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
        message.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var button = new Gtk.Button.from_icon_name ("window-close-symbolic") {
            valign = CENTER,
            halign = CENTER,
            tooltip_text = _("End this App"),
        };
        button.add_css_class ("circular");

        var spinner = new Gtk.Spinner () {
            spinning = true
        };

        var button_stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        button_stack.add_named (button, "button");
        button_stack.add_named (spinner, "spinner");

        var grid = new Gtk.Grid () {
            column_spacing = 9,
            row_spacing = 3,
            margin_top = 3,
            margin_bottom = 3,
            margin_start = 9,
            margin_end = 9
        };
        grid.attach (icon, 0, 0, 1, 2);

        if (app.message != null) {
            grid.attach (name, 1, 0, 1, 1);
            grid.attach (message, 1, 1, 1, 1);
        } else {
            grid.attach (name, 1, 0, 1, 2);
        }

        grid.attach (button_stack, 2, 0, 1, 2);

        width_request = 200;
        child = grid;

        button.clicked.connect (() => {
            button_stack.set_visible_child_name ("spinner");
            app.kill ();

            Timeout.add_seconds (5, () => {
                // Assume killing failed
                button_stack.set_visible_child_name ("button");
                return Source.REMOVE;
            });
        });
    }
}
