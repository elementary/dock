/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.AppCarouselPage : Granite.Bin {
    public const int COLUMNS = 5;
    public const int ROWS = 3;

    public ListModel apps { private get; construct; }

    public AppCarouselPage (ListModel apps) {
        Object (apps: apps);
    }

    private Gtk.Grid grid;

    construct {
        grid = new Gtk.Grid () {
            row_homogeneous = true,
            column_homogeneous = true,
            row_spacing = 36,
            column_spacing = 24,
        };
        grid.add_css_class ("app-grid");

        child = grid;
        hexpand = true;
        vexpand = true;

        apps.items_changed.connect (update_apps);
        update_apps ();
    }

    private void update_apps () {
        while (grid.get_first_child () != null) {
            grid.remove (grid.get_first_child ());
        }

        for (var row = 0; row < ROWS; row++) {
            for (var column = 0; column < COLUMNS; column++) {
                add_app (row, column);
            }
        }
    }

    private inline void add_app (int row, int column) {
        var n = row * COLUMNS + column;

        Gtk.Widget? widget;
        if (n >= apps.get_n_items ()) {
            widget = new Gtk.Grid ();
        } else {
            widget = new AppListItem ();
            ((AppListItem) widget).bind_app ((App) apps.get_item (n));
        }

        grid.attach (widget, column, row);
    }
}
