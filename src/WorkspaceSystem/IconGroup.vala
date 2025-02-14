/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.IconGroup : Gtk.Box {
    private class EmptyWidget : Gtk.Widget {}

    private const int MAX_IN_ROW = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_ROW;

    private static GLib.Settings dock_settings;

    public Workspace workspace { get; construct; }

    public signal void removed ();
    public signal void fade_done ();

    private Gtk.Grid grid;
    private Adw.TimedAnimation fade;
    private Adw.TimedAnimation timed_animation;

    public double current_pos { get; set; }

    class construct {
        set_css_name ("icongroup");
    }

    static construct {
        dock_settings = new Settings ("io.elementary.dock");
    }

    public IconGroup (Workspace workspace) {
        Object (workspace: workspace);
    }

    construct {
        grid = new Gtk.Grid () {
            hexpand = true,
            vexpand = true,
            halign = CENTER,
            valign = CENTER
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (grid);

        var running_indicator = new Gtk.Image.from_icon_name ("pager-checked-symbolic");
        running_indicator.add_css_class ("running-indicator");

        var running_revealer = new Gtk.Revealer () {
            can_target = false,
            child = running_indicator,
            overflow = VISIBLE,
            transition_type = CROSSFADE,
            valign = END
        };

        workspace.bind_property ("is-active-workspace", running_revealer, "reveal-child", SYNC_CREATE);

        orientation = VERTICAL;
        append (box);
        append (running_revealer);

        update_icons ();
        workspace.notify["windows"].connect (update_icons);
        dock_settings.changed["icon-size"].connect (update_icons);
        workspace.removed.connect (() => removed ());

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect (workspace.activate);

        dock_settings.bind ("icon-size", box, "width-request", DEFAULT);
        dock_settings.bind ("icon-size", box, "height-request", DEFAULT);

        fade = new Adw.TimedAnimation (
            this, 0, 1,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                opacity = val;
            })
        ) {
            easing = EASE_IN_OUT_QUAD
        };

        unowned var launcher_manager = ItemManager.get_default ();
        var animation_target = new Adw.CallbackAnimationTarget ((val) => {
            launcher_manager.move (this, val, 0);
            current_pos = val;
        });

        timed_animation = new Adw.TimedAnimation (
            this,
            0,
            0,
            200,
            animation_target
        ) {
            easing = EASE_IN_OUT_QUAD
        };
    }

    /**
     * Makes the launcher animate a move to the given position. Make sure to
     * always use this instead of manually calling Gtk.Fixed.move on the manager
     * when moving a launcher so that its current_pos is always up to date.
     */
    public void animate_move (double new_position) {
        timed_animation.value_from = current_pos;
        timed_animation.value_to = new_position;

        timed_animation.play ();
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
        for (i = 0; i < int.min (workspace.windows.size, 4); i++) {
            var image = new Gtk.Image.from_gicon (workspace.windows[i].icon) {
                pixel_size = new_pixel_size
            };

            grid.attach (image, i % MAX_IN_ROW, i / MAX_IN_ROW, 1, 1);
        }

        // We always need to attach at least 3 elements for grid to be square and properly aligned
        for (;i < 3; i++) {
            var empty_widget = new EmptyWidget ();
            empty_widget.set_size_request (new_pixel_size, new_pixel_size);

            grid.attach (empty_widget, i % MAX_IN_ROW, i / MAX_IN_ROW, 1, 1);
        }
    }

    private int get_pixel_size () {
        var icon_size = 8;
        var app_icon_size = dock_settings.get_int ("icon-size");

        switch (app_icon_size) {
            case 64:
                icon_size = 24;
                break;
            case 48:
                icon_size = 16;
                break;
            case 32:
                icon_size = 8;
                break;
            default:
                icon_size = (int) Math.round (app_icon_size / 3);
                break;
        }

        return icon_size;
    }

    private int get_grid_spacing () {
        var app_icon_size = dock_settings.get_int ("icon-size");
        var pixel_size = get_pixel_size ();

        return (int) Math.round ((app_icon_size - pixel_size * MAX_IN_ROW) / 3);
    }

    public void set_revealed (bool revealed) {
        fade.skip ();

        // Avoid a stutter at the beginning
        opacity = 0;
        // clip launcher to dock size until we finish animating
        overflow = HIDDEN;

        if (!revealed) {
            fade.duration = Granite.TRANSITION_DURATION_CLOSE;
            fade.reverse = true;
        }

        fade.play ();

        fade.done.connect (() => {
            overflow = VISIBLE;
            fade_done ();
        });
    }

    /**
     * If the icon group isn't needed anymore call this otherwise it won't be freed.
     */
    public void cleanup () {
        timed_animation = null;
    }
}
