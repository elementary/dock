/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public abstract class Dock.BaseIconGroup : ContainerItem {
    private const int MAX_IN_ROW = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_ROW;

    public ListModel icons { get; construct; }

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

        child = flow_box;
    }

    private static Gtk.Widget create_flow_box_child (Object item) {
        return new Gtk.FlowBoxChild () {
            child = new CustomImage ((Icon) item),
            can_focus = false,
            can_target = false
        };
    }

    private class CustomImage : Granite.Bin {
        private const string ICON_SIZE = "icon-size";
        private static Settings settings = new Settings ("io.elementary.dock");

        public Gtk.Image image { private get; construct; }

        public CustomImage (Icon icon) {
            Object (image: new Gtk.Image.from_gicon (icon));
        }

        construct {
            child = image;

            settings.changed[ICON_SIZE].connect (on_icon_size_changed);
            on_icon_size_changed ();
        }

        private void on_icon_size_changed () {
            var new_icon_size = settings.get_int (ICON_SIZE);
            var new_pixel_size = icon_size_to_pixel_size (new_icon_size);

            image.pixel_size = new_pixel_size;

            // We use margin instead of grid spacing because grid spacing in combination with
            // min children per line causes the flow box to request the grid spacing as additional width
            // even when there is only one child making it off center.
            var margin = (new_icon_size - new_pixel_size * MAX_IN_ROW) / 6;
            margin_start = margin;
            margin_top = margin;
            margin_end = margin;
            margin_bottom = margin;
        }

        private static int icon_size_to_pixel_size (int icon_size) {
            switch (icon_size) {
                case 64: return 24;
                case 48: return 16;
                case 32: return 8;
                default: return (int) Math.round (icon_size / 3);
            }
        }
    }
}
