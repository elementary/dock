/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.WorkspaceIconGroup : BaseIconGroup {
    public override Dock.BaseItem.Group group { get { return Group.WORKSPACE; } }
    public Workspace workspace { get; construct; }

    public GLib.ListStore additional_icons { private get; construct; }

    public WorkspaceIconGroup (Workspace workspace) {
        var additional_icons = new GLib.ListStore (typeof (GLib.Icon));

        var workspace_icons = new Gtk.MapListModel (workspace.windows, (window) => {
            return ((Window) window).icon;
        });

        var icon_sources_list_store = new GLib.ListStore (typeof (GLib.ListModel));
        icon_sources_list_store.append (additional_icons);
        icon_sources_list_store.append (workspace_icons);

        var flatten_model = new Gtk.FlattenListModel (icon_sources_list_store);

        Object (
            workspace: workspace,
            additional_icons: additional_icons,
            icons: flatten_model
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
    }

    protected override void on_stop_moving () {
        workspace.reorder (ItemManager.get_default ().get_index_for_launcher (this));
    }

    public void window_entered (Window window) {
        if (window.workspace_index == workspace.index) {
            return;
        }

        additional_icons.append (window.icon);
    }

    public void window_left () {
        additional_icons.remove_all ();
    }
}
