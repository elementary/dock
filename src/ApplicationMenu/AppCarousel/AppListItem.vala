/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.AppListItem : Gtk.Button {
    private const int ICON_SIZE = 64;

    private Granite.Bin app_icon_container;
    private new Gtk.Label label;
    private Gtk.Popover? popover_menu;

    construct {
        app_icon_container = new Granite.Bin ();

        label = new Gtk.Label (null) {
            ellipsize = END,
            wrap_mode = WORD_CHAR,
            max_width_chars = 16,
            width_chars = 16,
            lines = 2,
            justify = CENTER,
        };

        var box = new Granite.Box (VERTICAL);
        box.append (app_icon_container);
        box.append (label);

        child = box;
        add_css_class ("flat");

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        gesture_click.released.connect (on_secondary_click);
        add_controller (gesture_click);
    }

    private void on_secondary_click (int n_press, double x, double y) {
        if (popover_menu == null) {
            return;
        }

        popover_menu.set_pointing_to ({ (int) x, (int) y, 0, 0 });
        popover_menu.popup ();
    }

    public void bind_app (App app) {
        app_icon_container.child = new AppIconWidget (app) {
            icon_size = ICON_SIZE
        };
        label.label = app.app_info.get_display_name ();

        popover_menu = AppMenuFactory.create_app_menu (app);
        popover_menu.has_arrow = false;
        popover_menu.halign = START;
        popover_menu.position = BOTTOM;
        popover_menu.set_parent (this);
    }
}
