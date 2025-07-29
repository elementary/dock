/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundItem : BaseIconGroup {
    public signal void apps_appeared ();

    public BackgroundMonitor monitor { private get; construct; }
    public bool has_apps { get { return monitor.background_apps.get_n_items () > 0; } }

    private Gtk.Popover popover;

    public BackgroundItem () {
        var background_monitor = new BackgroundMonitor ();
        Object (
            monitor: background_monitor,
            icons: new Gtk.MapListModel (background_monitor.background_apps, (app) => {
                return ((BackgroundApp) app).icon;
            }),
            disallow_dnd: true
        );
    }

    construct {
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

        monitor.background_apps.items_changed.connect ((pos, n_removed, n_added) => {
            if (monitor.background_apps.get_n_items () == 0) {
                popover.popdown ();
                removed ();
            } else if (n_removed == 0 && n_added != 0 && n_added == monitor.background_apps.get_n_items ()) {
                apps_appeared ();
            }
        });

        gesture_click.released.connect (popover.popup);
    }

    private Gtk.Widget create_widget_func (Object obj) {
        var app = (BackgroundApp) obj;
        return new BackgroundAppRow (app);
    }

    public void load () {
        monitor.load ();
    }

    public override void cleanup () {
        // Do nothing here since we reuse this item
    }
}
