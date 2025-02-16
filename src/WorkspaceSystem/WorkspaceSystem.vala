/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Dock.WorkspaceSystem : Object {
    private static GLib.Once<WorkspaceSystem> instance;
    public static unowned WorkspaceSystem get_default () {
        return instance.once (() => { return new WorkspaceSystem (); });
    }

    public signal void workspace_added (Workspace workspace);
    public signal void workspace_removed ();

    public Gee.List<Workspace> workspaces { get; private owned set; }

    private WorkspaceSystem () { }

    construct {
        workspaces = new Gee.ArrayList<Workspace> ();
    }

    public async void load () {
        yield sync_windows ();

        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
        WindowSystem.get_default ().notify["active-workspace"].connect (sync_active_workspace);
        WindowSystem.get_default ().workspace_removed.connect (remove_workspace);
    }

    private Workspace add_workspace () {
        var workspace = new Workspace ();
        workspaces.add (workspace);
        workspace_added (workspace);
        return workspace;
    }

    private async void sync_windows () {
        unowned var window_system = WindowSystem.get_default ();
        var n_workspaces = window_system.n_workspaces;

        var workspace_window_list = new Gee.ArrayList<Gee.List<Window>> ();
        for (var i = 0; i < n_workspaces; i++) {
            workspace_window_list.add (new Gee.LinkedList<Window> ());
        }

        foreach (var window in window_system.windows) {
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
            if (i < workspaces.size) {
                workspace = workspaces[i];
            } else {
                workspace = add_workspace ();
            }

            workspace.windows = workspace_window_list[i];
            workspace.index = i;
            workspace.update_active_workspace ();
        }
    }

    private async void sync_active_workspace () {
        foreach (var workspace in workspaces) {
            workspace.update_active_workspace ();
        }
    }

    private async void remove_workspace (int index) {
        // if workspace is the second last and empty, the last workspace is being removed
        // but since the last workspace is static in the dock we remove second last workspace instead;
        if (index == WindowSystem.get_default ().n_workspaces - 1) {
            index--;
        }

        workspaces[index].remove ();
        workspaces.remove_at (index);
        workspace_removed ();
    }
}
