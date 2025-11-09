/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public abstract class Dock.BaseIconGroup : BaseItem {
    private const int MAX_IN_ROW = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_ROW;

    public ListModel icons { get; construct; }

    class construct {
        set_css_name ("icongroup");
    }

    construct {
        var slice = new Gtk.SliceListModel (icons, 0, MAX_N_CHILDREN);

        var flow_box = new Gtk.FlowBox () {
            max_children_per_line = MAX_IN_ROW,
            min_children_per_line = MAX_IN_ROW,
            selection_mode = NONE,
            halign = CENTER,
            valign = CENTER,
        };
        flow_box.bind_model (slice, create_flow_box_child);

        var bin = new Adw.Bin () {
            child = flow_box
        };
        bin.add_css_class ("icon-group-bin");
        bind_property ("icon-size", bin, "width-request", SYNC_CREATE);
        bind_property ("icon-size", bin, "height-request", SYNC_CREATE);

        overlay.child = bin;
    }

    private Gtk.Widget create_flow_box_child (Object? item) {
        var image = new Gtk.Image.from_gicon ((Icon) item);
        bind_property ("icon-size", image, "pixel-size", SYNC_CREATE, (binding, from_value, ref to_value) => {
            var icon_size = from_value.get_int ();
            to_value.set_int (get_pixel_size (icon_size));
            return true;
        });
        // We use margin instead of grid spacing because grid spacing in combination with
        // min children per line causes the flow box to request the grid spacing as additional width
        // even when there is only one child making it off center.
        bind_property ("icon-size", image, "margin-start", SYNC_CREATE, icon_size_to_margin);
        bind_property ("icon-size", image, "margin-top", SYNC_CREATE, icon_size_to_margin);
        bind_property ("icon-size", image, "margin-end", SYNC_CREATE, icon_size_to_margin);
        bind_property ("icon-size", image, "margin-bottom", SYNC_CREATE, icon_size_to_margin);

        return new Gtk.FlowBoxChild () {
            child = image,
            can_target = false
        };
    }

    private static bool icon_size_to_margin (Binding binding, Value from_value, ref Value to_value) {
        var icon_size = from_value.get_int ();
        var pixel_size = get_pixel_size (icon_size);
        var spacing = (int) Math.round ((icon_size - pixel_size * MAX_IN_ROW) / 6);
        to_value.set_int (spacing);
        return true;
    }

    private static int get_pixel_size (int for_icon_size) {
        switch (for_icon_size) {
            case 64: return 24;
            case 48: return 16;
            case 32: return 8;
            default: return (int) Math.round (for_icon_size / 3);
        }
    }
}
