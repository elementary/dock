/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundItem : BaseItem {
    private BackgroundMonitor monitor;

    private Gtk.Popover popover;

    construct {
        monitor = new BackgroundMonitor ();

        var list_box = new Gtk.ListBox () {
            selection_mode = NONE,
            margin_bottom = 3,
            margin_top = 3,
        };
        list_box.bind_model (monitor.background_apps, create_widget_func);
        list_box.set_placeholder (new Gtk.Label (_("No apps are running in the background")));

        popover = new Gtk.Popover () {
            position = TOP,
            child = list_box
        };
        popover.set_parent (this);

        var image = new Gtk.Image.from_resource ("/io/elementary/dock/background.svg");
        bind_property ("icon-size", image, "pixel-size", SYNC_CREATE);

        overlay.child = image;

        gesture_click.released.connect (popover.popup);
    }

    private Gtk.Widget create_widget_func (Object obj) {
        var app = (BackgroundApp) obj;
        return new BackgroundAppRow (app);
    }
}
