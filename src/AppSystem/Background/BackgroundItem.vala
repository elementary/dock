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

        var placeholder = new Granite.Placeholder (_("No apps running in the background"));

        var list_box = new Gtk.ListBox () {
            selection_mode = BROWSE
        };
        list_box.bind_model (monitor.background_apps, create_widget_func);
        list_box.set_placeholder (placeholder);

        var header_label = new Granite.HeaderLabel (_("Background Apps")) {
            mnemonic_widget = list_box,
            secondary_text = _("Apps running without a visible window.")
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (header_label);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (list_box);

        popover = new Gtk.Popover () {
            position = TOP,
            child = box
        };
        popover.add_css_class (Granite.STYLE_CLASS_MENU);
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
