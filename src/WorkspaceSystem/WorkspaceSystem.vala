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

    public Gee.List<Workspace> workspaces { get; private owned set; }

    private WorkspaceSystem () { }

    construct {
        workspaces = new Gee.ArrayList<Workspace> ();
    }

    public async void load () {
        yield sync_windows ();

        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
        WindowSystem.get_default ().notify["active-workspace"].connect (sync_active_workspace);
    }

    private Workspace add_workspace (int workspace_index) {
        var workspace = new Workspace ();
        workspaces.insert (workspace_index, workspace);
        workspace.removed.connect_after ((_workspace) => workspaces.remove (_workspace));
        workspace_added (workspace);
        return workspace;
    }

    public async void sync_windows () {
        if (WindowSystem.get_default ().desktop_integration == null) {
            return;
        }

        int n_workspaces;
        try {
            n_workspaces = yield WindowSystem.get_default ().desktop_integration.get_n_workspaces ();
        } catch (Error e) {
            critical (e.message);
            return;
        }
        
        var workspace_window_list = new Gee.ArrayList<Gee.List<Window>> ();
        for (var i = 0; i < n_workspaces; i++) {
            workspace_window_list.add (new Gee.LinkedList<Window> ());
        }

        foreach (var window in WindowSystem.get_default ().windows) {
            workspace_window_list[window.workspace_index].add (window);
        }

        // cleanup extra workspaces
        for (var i = n_workspaces; i < workspaces.size; i++) {
            workspaces[i].remove ();
        }

        // update windows in existing workspaces
        for (var i = 0; i < n_workspaces; i++) {
            Workspace workspace;
            if (i < workspaces.size) {
                workspace = workspaces[i];
            } else {
                workspace = add_workspace (i);
            }

            workspace.windows = workspace_window_list[i];
            workspace.index = i;
            workspace.is_last_workspace = (i == n_workspaces - 1);
            workspace.update_active_workspace ();
        }
    }

    private async void sync_active_workspace () {
        foreach (var workspace in workspaces) {
            workspace.update_active_workspace ();
        }
    }
}
