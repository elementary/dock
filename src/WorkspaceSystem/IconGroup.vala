/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.WorkspaceIconGroup : BaseIconGroup {
    public Workspace workspace { get; construct; }

    public WorkspaceIconGroup (Workspace workspace) {
        Object (
            workspace: workspace,
            icons: new Gtk.MapListModel (workspace.windows, (window) => {
                return ((Window) window).icon;
            }),
            group: Group.WORKSPACE
        );
    }

    construct {
        workspace.bind_property ("is-active-workspace", this, "state", SYNC_CREATE, (binding, from_value, ref to_value) => {
            var new_val = from_value.get_boolean () ? State.ACTIVE : State.HIDDEN;
            to_value.set_enum (new_val);
            return true;
        });

        workspace.removed.connect (() => removed ());

        gesture_click.button = Gdk.BUTTON_PRIMARY;
        gesture_click.released.connect (workspace.activate);

        notify["moving"].connect (on_moving_changed);
    }

    private void on_moving_changed () {
        if (!moving) {
            workspace.reorder (ItemManager.get_default ().get_index_for_launcher (this));
        }
    }
}
