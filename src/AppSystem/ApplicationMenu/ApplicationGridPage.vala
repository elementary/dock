/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.ApplicationGridPage : Granite.Bin {
    public const int PAGE_SIZE = 20;

    public ListModel apps { get; construct; }
    public int page { get; construct; }

    private Gtk.SliceListModel slice_model;

    public ApplicationGridPage (ListModel apps, int page) {
        Object (apps: apps, page: page);
    }

    construct {
        slice_model = new Gtk.SliceListModel (apps, page * PAGE_SIZE, PAGE_SIZE);

        var flow_box = new Gtk.FlowBox () {
            max_children_per_line = 5,
            min_children_per_line = 5,
            homogeneous = true,
            selection_mode = NONE,
            row_spacing = 12,
            column_spacing = 12,
        };
        flow_box.bind_model (slice_model, create_widget);

        hexpand = true;
        child = flow_box;
    }

    private Gtk.Widget create_widget (Object item) {
        var app = (App) item;
        return new ApplicationButton (app);
    }
}
