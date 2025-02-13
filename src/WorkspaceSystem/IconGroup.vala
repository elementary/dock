/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.IconGroup : Gtk.Box {
    private const int MAX_IN_ROW = 2;
    private const int MAX_IN_COLUMN = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_COLUMN;

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
        grid = new Gtk.Grid ();
        grid.add_css_class ("grid");

        var running_indicator = new Gtk.Image.from_icon_name ("pager-checked-symbolic");
        running_indicator.add_css_class ("running-indicator");

        var running_revealer = new Gtk.Revealer () {
            can_target = false,
            child = running_indicator,
            overflow = VISIBLE,
            transition_type = CROSSFADE,
            valign = END
        };

        orientation = VERTICAL;
        append (grid);
        append (running_revealer);

        update_icons ();
        workspace.notify["windows"].connect (update_icons);
        workspace.removed.connect (() => removed ());

        var gesture_click = new Gtk.GestureClick () {
            button = 0
        };
        add_controller (gesture_click);
        gesture_click.released.connect (workspace.activate);

        dock_settings.bind ("icon-size", grid, "width-request", DEFAULT);
        dock_settings.bind ("icon-size", grid, "height-request", DEFAULT);

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

        for (var i = 0; i < int.min (workspace.windows.size, 4); i++) {
            var image = new Gtk.Image.from_gicon (workspace.windows[i].icon) {
                pixel_size = 24
            };

            grid.attach (image, i % MAX_IN_ROW, i / MAX_IN_COLUMN, 1, 1);
        }

        if (workspace.is_last_workspace && workspace.windows.is_empty) {
            add_css_class ("dynamic");
        } else {
            remove_css_class ("dynamic");
        }
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
