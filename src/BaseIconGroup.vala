/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public abstract class Dock.BaseIconGroup : BaseItem {
    private class EmptyWidget : Gtk.Widget {}

    private const int MAX_IN_ROW = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_ROW;

    public ListModel icons { get; construct; }

    private Gtk.Grid grid;

    class construct {
        set_css_name ("icongroup");
    }

    construct {
        grid = new Gtk.Grid () {
            hexpand = true,
            vexpand = true,
            halign = CENTER,
            valign = CENTER
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add_css_class ("icon-group-box");
        box.append (grid);

        overlay.child = box;

        update_icons ();
        icons.items_changed.connect (update_icons);
        notify["icon-size"].connect (update_icons);

        bind_property ("icon-size", box, "width-request", SYNC_CREATE);
        bind_property ("icon-size", box, "height-request", SYNC_CREATE);
    }

    private void update_icons () {
        unowned Gtk.Widget? child;
        while ((child = grid.get_first_child ()) != null) {
            grid.remove (child);
        }

        var grid_spacing = get_grid_spacing ();
        grid.row_spacing = grid_spacing;
        grid.column_spacing = grid_spacing;

        var new_pixel_size = get_pixel_size ();
        int i;
        for (i = 0; i < uint.min (icons.get_n_items (), 4); i++) {
            var image = new Gtk.Image.from_gicon ((Icon) icons.get_item (i)) {
                pixel_size = new_pixel_size
            };

            grid.attach (image, i % MAX_IN_ROW, i / MAX_IN_ROW, 1, 1);
        }

        // We always need to attach at least 3 elements for grid to be square and properly aligned
        for (; i < 3; i++) {
            var empty_widget = new EmptyWidget ();
            empty_widget.set_size_request (new_pixel_size, new_pixel_size);

            grid.attach (empty_widget, i % MAX_IN_ROW, i / MAX_IN_ROW, 1, 1);
        }
    }

    private int get_pixel_size () {
        var pixel_size = 8;

        switch (icon_size) {
            case 64:
                pixel_size = 24;
                break;
            case 48:
                pixel_size = 16;
                break;
            case 32:
                pixel_size = 8;
                break;
            default:
                pixel_size = (int) Math.round (icon_size / 3);
                break;
        }

        return pixel_size;
    }

    private int get_grid_spacing () {
        var pixel_size = get_pixel_size ();

        return (int) Math.round ((icon_size - pixel_size * MAX_IN_ROW) / 3);
    }
}
