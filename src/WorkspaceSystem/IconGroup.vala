/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.IconGroup : BaseItem {
    private class EmptyWidget : Gtk.Widget {}

    private const int MAX_IN_ROW = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_ROW;

    public Workspace workspace { get; construct; }

    private Gtk.Grid grid;

    private Window? hovering_window = null;

    class construct {
        set_css_name ("icongroup");
    }

    public IconGroup (Workspace workspace) {
        Object (workspace: workspace, group: Group.WORKSPACE);
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

        workspace.bind_property ("is-active-workspace", this, "state", SYNC_CREATE, (binding, from_value, ref to_value) => {
            var new_val = from_value.get_boolean () ? State.ACTIVE : State.HIDDEN;
            to_value.set_enum (new_val);
            return true;
        });

        update_icons ();
        workspace.notify["windows"].connect (update_icons);
        notify["icon-size"].connect (update_icons);

        bind_property ("icon-size", box, "width-request", SYNC_CREATE);
        bind_property ("icon-size", box, "height-request", SYNC_CREATE);

        workspace.removed.connect (() => removed ());

        gesture_click.button = Gdk.BUTTON_PRIMARY;
        gesture_click.released.connect (workspace.activate);

        notify["moving"].connect (on_moving_changed);
    }

    public void window_entered (Window window) {
        if (window.workspace_index == workspace.index) {
            return;
        }

        hovering_window = window;
        update_icons ();
    }

    public void window_left () {
        hovering_window = null;
        update_icons ();
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
        int nth_window = 0;

        if (hovering_window != null) {
            grid.attach (new Gtk.Image.from_gicon (hovering_window.icon) {
                pixel_size = new_pixel_size
            }, 0, 0);
            nth_window++;
        }

        var n = int.min (workspace.windows.length, 4 - nth_window);
        for (int i = 0; i < n; i++) {
            var image = new Gtk.Image.from_gicon (workspace.windows[i].icon) {
                pixel_size = new_pixel_size
            };

            grid.attach (image, nth_window % MAX_IN_ROW, nth_window / MAX_IN_ROW, 1, 1);
            nth_window++;
        }

        // We always need to attach at least 3 elements for grid to be square and properly aligned
        for (; nth_window < 3; nth_window++) {
            var empty_widget = new EmptyWidget ();
            empty_widget.set_size_request (new_pixel_size, new_pixel_size);

            grid.attach (empty_widget, nth_window % MAX_IN_ROW, nth_window / MAX_IN_ROW, 1, 1);
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

    private void on_moving_changed () {
        if (!moving) {
            workspace.reorder (ItemManager.get_default ().get_index_for_launcher (this));
        }
    }

    /**
     * {@inheritDoc}
     */
    public override void cleanup () {
        base.cleanup ();
    }
}
