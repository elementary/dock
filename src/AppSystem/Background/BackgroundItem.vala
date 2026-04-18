/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundItem : BaseIconGroup {
    private ListStore group_store;
    public ListModel group_model { get { return group_store; } }

    public BackgroundMonitor monitor { private get; construct; }

    public BackgroundItem () {
        var background_monitor = new BackgroundMonitor ();
        Object (
            monitor: background_monitor,
            icons: new Gtk.MapListModel (background_monitor.background_apps, (app) => {
                return ((BackgroundApp) app).icon;
            }),
            group: Group.NONE
        );
    }

    construct {
        group_store = new ListStore (typeof (BackgroundItem));

        var list_box = new Gtk.ListBox () {
            selection_mode = BROWSE
        };
        list_box.bind_model (monitor.background_apps, create_widget_func);

        var header_label = new Granite.HeaderLabel (_("Background Apps")) {
            mnemonic_widget = list_box,
            secondary_text = _("Apps running without a visible window.")
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (header_label);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (list_box);

        popover_menu = new Gtk.Popover () {
            position = TOP,
            child = box
        };
        // We need to set offset because dock window's height is 1px larger than its visible area
        // If we don't do that, the struts prevent popover from showing
        popover_menu.set_offset (0, -1);
        popover_menu.add_css_class (Granite.STYLE_CLASS_MENU);
        popover_menu.set_parent (this);

        tooltip_text = "%s\n%s".printf (
            header_label.label,
            Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (header_label.secondary_text)
        );

        list_box.row_activated.connect ((row) => {
            popover_menu.popdown ();

            var app = ((BackgroundAppRow) row).app;
            try {
                app.app_info.launch (null, Gdk.Display.get_default ().get_app_launch_context ());
            } catch (Error e) {
                critical (e.message);
            }
        });

        monitor.background_apps.items_changed.connect ((pos, n_removed, n_added) => {
            if (monitor.background_apps.get_n_items () == 0) {
                popover_menu.popdown ();
                group_store.remove (0);
            } else if (n_removed == 0 && n_added != 0 && n_added == monitor.background_apps.get_n_items ()) {
                group_store.append (this);
            }
        });

        gesture_click.released.connect (popover_menu.popup);
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
