/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.DynamicWorkspaceIcon : Gtk.Box {
    public double current_pos { get; set; }

    private Gtk.Revealer running_revealer;
    private Adw.TimedAnimation timed_animation;

    class construct {
        set_css_name ("icongroup");
    }

    construct {
        var add_image = new Gtk.Image.from_icon_name ("list-add-symbolic") {
            hexpand = true,
            vexpand = true
        };
        add_image.add_css_class ("add-image");

        // Gtk.Box is used here to keep css nodes consistent with IconGroup
        var box = new Gtk.Box (VERTICAL, 0);
        box.append (add_image);

        var running_indicator = new Gtk.Image.from_icon_name ("pager-checked-symbolic");
        running_indicator.add_css_class ("running-indicator");

        running_revealer = new Gtk.Revealer () {
            can_target = false,
            child = running_indicator,
            overflow = VISIBLE,
            transition_type = CROSSFADE,
            valign = END
        };

        orientation = VERTICAL;
        append (box);
        append (running_revealer);

        WorkspaceSystem.get_default ().workspace_added.connect (update_running_indicator_visibility);
        WorkspaceSystem.get_default ().workspace_removed.connect (update_running_indicator_visibility);
        WindowSystem.get_default ().notify["active-workspace"].connect (update_running_indicator_visibility);

        DockSettings.get_default ().bind_property ("icon-size", box, "width-request", SYNC_CREATE);
        DockSettings.get_default ().bind_property ("icon-size", box, "height-request", SYNC_CREATE);

        DockSettings.get_default ().bind_property (
            "icon-size", add_image, "pixel-size", SYNC_CREATE,
            (binding, source_value, ref target_value) => {
                var icon_size = source_value.get_int ();
                target_value.set_int (icon_size / 2);
                return true; 
            }
        );

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect (switch_to_new_workspace);

        unowned var item_manager = ItemManager.get_default ();
        var animation_target = new Adw.CallbackAnimationTarget ((val) => {
            item_manager.move (this, val, 0);
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

    private void update_running_indicator_visibility () {
        unowned var workspace_system = WorkspaceSystem.get_default ();
        unowned var window_system = WindowSystem.get_default ();
        running_revealer.reveal_child = workspace_system.workspaces.size == window_system.active_workspace;
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

    private async void switch_to_new_workspace () {
        var n_workspaces = WorkspaceSystem.get_default ().workspaces.size;

        try {
            yield WindowSystem.get_default ().desktop_integration.activate_workspace (n_workspaces);
        } catch (Error e) {
            warning ("Couldn't switch to new workspace: %s", e.message);
        }
    }
}
