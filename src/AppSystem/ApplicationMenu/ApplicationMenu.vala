/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.ApplicationMenu : Gtk.Popover {
    public const int WIDTH = 600;
    public const int HEIGHT = 600;

    construct {
        var overlay = new Gtk.Overlay () {
            child = new Container (),
        };
        overlay.add_overlay (new ApplicationGrid ());

        position = TOP;
        has_arrow = false;
        height_request = WIDTH;
        width_request = HEIGHT;
        margin_bottom = 12;
        child = overlay;
        remove_css_class (Granite.STYLE_CLASS_BACKGROUND);
    }

    public void toggle () {
        popup ();
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        base.snapshot (snapshot);
        // We need to append something here otherwise GTK thinks the snapshot is empty and therefore doesn't
        // render anything and therefore doesn't present a window which is needed for our popovers
        snapshot.append_color ({0, 0, 0, 0}, {{0, 0}, {0, 0}});
    }
}
