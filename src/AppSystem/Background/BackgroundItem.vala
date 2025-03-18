/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundItem : BaseItem {
    private BackgroundMonitor monitor;

    private Gtk.Popover popover;

    class construct {
        set_css_name ("backgrounditem");
    }

    construct {
        monitor = new BackgroundMonitor ();

        var header_icon = new Gtk.Image.from_icon_name ("background") {
            icon_size = LARGE
        };

        var header_label = new Gtk.Label (_("Background Apps")) {
            xalign = 0,
        };

        var description_label = new Gtk.Label (_("These apps are running without a visible window.")) {
            xalign = 0,
        };
        description_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var header_grid = new Gtk.Grid () {
            margin_start = 9,
            margin_end = 9,
            column_spacing = 9,
        };
        header_grid.attach (header_icon, 0, 0, 1, 2);
        header_grid.attach (header_label, 1, 0, 1, 1);
        header_grid.attach (description_label, 1, 1, 1, 1);

        var placeholder = new Granite.Placeholder (_("No apps running in the background"));

        var list_box = new Gtk.ListBox () {
            selection_mode = NONE,
        };
        list_box.bind_model (monitor.background_apps, create_widget_func);
        list_box.set_placeholder (placeholder);

        var box = new Gtk.Box (VERTICAL, 6) {
            margin_top = 12,
            margin_bottom = 6,
        };
        box.append (header_grid);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (list_box);

        popover = new Gtk.Popover () {
            position = TOP,
            child = box
        };
        popover.set_parent (this);

        var image = new Gtk.Image.from_icon_name ("background");
        bind_property ("icon-size", image, "pixel-size", SYNC_CREATE);

        overlay.child = image;

        monitor.background_apps.bind_property (
            "n-items", this, "state", SYNC_CREATE, (binding, from_value, ref to_value) => {
                var new_val = from_value.get_uint () > 0 ? State.INACTIVE : State.HIDDEN;
                to_value.set_enum (new_val);
                return true;
            }
        );

        gesture_click.released.connect (popover.popup);
    }

    private Gtk.Widget create_widget_func (Object obj) {
        var app = (BackgroundApp) obj;
        return new BackgroundAppRow (app);
    }
}
