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

    private Gtk.PopoverMenu popover;
    private Gtk.Image image;

    public ApplicationButton (App app) {
        Object (app: app);
    }

    construct {
        popover = new Gtk.PopoverMenu.from_model (app.menu_model) {
            autohide = true,
            position = BOTTOM,
            has_arrow = false,
            halign = START
        };
        popover.set_parent (this);

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

        insert_action_group (App.ACTION_GROUP_PREFIX, app.action_group);

        var long_press = new Gtk.GestureLongPress ();
        add_controller (long_press);
        long_press.pressed.connect (popup_menu);

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect ((n_press, x, y) => popup_menu (x, y));

        button.clicked.connect (on_clicked);

        // The AppSystem might not know about this app (if it's not running in the dock)
        // so we have to actually call pin
        app.notify["pinned"].connect (() => {
            if (app.pinned) {
                AppSystem.get_default ().add_app_for_id (app.app_info.get_id ());
            }
        });
    }

    private void on_clicked () {
        var popover = (Gtk.Popover) get_ancestor (typeof (Gtk.Popover));
        popover.popdown ();

        app.launch (Gdk.Display.get_default ().get_app_launch_context ());
    }

    private void popup_menu (double x, double y) {
        popover.set_pointing_to ({ (int) x, (int) y });
        popover.popup ();
    }
}
