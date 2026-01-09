/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Dock.WorkspaceSystem : Object {
    private static GLib.Once<WorkspaceSystem> instance;
    public static unowned WorkspaceSystem get_default () {
        return instance.once (() => { return new WorkspaceSystem (); });
    }

    public ListStore workspaces { get; private owned set; }

    private WorkspaceSystem () { }

    construct {
        workspaces = new ListStore (typeof (Workspace));
    }

    public async void load () {
        yield sync_windows ();

        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
        WindowSystem.get_default ().notify["active-workspace"].connect (sync_active_workspace);
        WindowSystem.get_default ().workspace_removed.connect (remove_workspace);
    }

    private Workspace add_workspace () {
        var workspace = new Workspace ();
        workspaces.append (workspace);
        return workspace;
    }

    private async void sync_windows () {
        // We subtract 1 because we have separate button for dynamic workspace
        var n_workspaces = (yield get_n_workspaces ()) - 1;

        var workspace_window_list = new GLib.GenericArray<GLib.GenericArray<Window>> ();
        for (var i = 0; i < n_workspaces; i++) {
            workspace_window_list.add (new GLib.GenericArray<Window> ());
        }

        foreach (var window in WindowSystem.get_default ().windows) {
            var workspace_index = window.workspace_index;

            if (workspace_index < 0 || workspace_index >= n_workspaces) {
                warning ("WorkspaceSystem.sync_windows: Unexpected window workspace index: %d", workspace_index);
                continue;
            }

            workspace_window_list[workspace_index].add (window);
        }

        // update windows in existing workspaces
        for (var i = 0; i < n_workspaces; i++) {
            Workspace workspace;
            if (i < workspaces.get_n_items ()) {
                workspace = (Workspace) workspaces.get_item (i);
            } else {
                workspace = add_workspace ();
            }

            workspace_window_list[i].sort (compare_func);

            workspace.update_windows (workspace_window_list[i]);
            workspace.index = i;
            workspace.update_active_workspace ();
        }
    }

    private static int compare_func (Window a, Window b) {
        return (int) (a.time_appeared_on_workspace - b.time_appeared_on_workspace);
    }

    private async void sync_active_workspace () {
        for (uint i = 0; i < workspaces.get_n_items (); i++) {
            var workspace = (Workspace) workspaces.get_item (i);
            workspace.update_active_workspace ();
        }
    }

    private async void remove_workspace (int index) {
        if (index == (yield get_n_workspaces ())) {
            index--;
        }

        workspaces.remove (index);
    }

    private async int get_n_workspaces () {
        if (WindowSystem.get_default ().desktop_integration == null) {
            critical ("DesktopIntegration is null");
            return 0;
        }

        try {
            return yield WindowSystem.get_default ().desktop_integration.get_n_workspaces ();
        } catch (Error e) {
            critical (e.message);
            return 0;
        }
    }

    public void reorder_workspace (Workspace workspace, int new_index) {
        uint pos;
        if (!workspaces.find (workspace, out pos)) {
            warning ("Tried to reorder a workspace that is not in the store");
            return;
        }

        workspaces.remove (pos);
        workspaces.insert (new_index, workspace);

        WindowSystem.get_default ().desktop_integration.reorder_workspace.begin (workspace.index, new_index);
    }
}
