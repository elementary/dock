/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.DynamicWorkspaceIcon : BaseItem {
    class construct {
        set_css_name ("icongroup");
    }

    public DynamicWorkspaceIcon () {
        Object (disallow_dnd: true, group: Group.WORKSPACE);
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

        overlay.child = box;

        WorkspaceSystem.get_default ().workspace_added.connect (update_active_state);
        WorkspaceSystem.get_default ().workspace_removed.connect (update_active_state);
        WindowSystem.get_default ().notify["active-workspace"].connect (update_active_state);

        dock_settings.bind ("icon-size", box, "width-request", DEFAULT);
        dock_settings.bind ("icon-size", box, "height-request", DEFAULT);

        dock_settings.bind_with_mapping (
            "icon-size", add_image, "pixel_size", DEFAULT | GET,
            (value, variant, user_data) => {
                var icon_size = variant.get_int32 ();
                value.set_int (icon_size / 2);
                return true;
            },
            (value, expected_type, user_data) => {
                return new Variant.maybe (null, null);
            },
            null, null
        );

        gesture_click.button = Gdk.BUTTON_PRIMARY;
        gesture_click.released.connect (switch_to_new_workspace);
    }

    private void update_active_state () {
        unowned var workspace_system = WorkspaceSystem.get_default ();
        unowned var window_system = WindowSystem.get_default ();
        state = (workspace_system.workspaces.length == window_system.active_workspace) ? State.ACTIVE : State.HIDDEN;
    }

    private async void switch_to_new_workspace () {
        var n_workspaces = WorkspaceSystem.get_default ().workspaces.length;
        var index = WindowSystem.get_default ().active_workspace;

        if (index == n_workspaces) {
            GalaDBus.open_multitaksing_view ();
            return;
        }

        try {
            yield WindowSystem.get_default ().desktop_integration.activate_workspace (n_workspaces);
        } catch (Error e) {
            warning ("Couldn't switch to new workspace: %s", e.message);
        }
    }
}
