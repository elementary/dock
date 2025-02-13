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
        WindowSystem.get_default ().windows_changed.connect (sync_windows);
        yield sync_windows ();
    }

    private Workspace add_workspace (int workspace_index) {
        var workspace = new Workspace ();
        workspaces.insert (workspace_index, workspace);
        workspace.removed.connect ((_workspace) => workspaces.remove (_workspace));
        workspace_added (workspace);
        return workspace;
    }

    public async void sync_windows () {
        warning ("Syncing windows");

        var windows = WindowSystem.get_default ().windows;

        var workspace_window_list = new Gee.HashMap<int, Gee.List<Window>> ();
        foreach (var window in windows) {
            var workspace_index = window.workspace_index;

            Workspace workspace;
            if (workspace_index < workspaces.size) {
                workspace = workspaces[workspace_index];
            } else {
                workspace = add_workspace (workspace_index);
            }

            var window_list = workspace_window_list.get (workspace_index);
            if (window_list == null) {
                var new_window_list = new Gee.LinkedList<Window> ();
                new_window_list.add (window);
                workspace_window_list.set (workspace_index, new_window_list);
            } else {
                window_list.add (window);
            }
        }

        for (var i = 0; i < workspaces.size; i++) {
            Gee.List<Window>? window_list = null;
            workspace_window_list.unset (i, out window_list);
            workspaces[i].update_windows (window_list);
        }
    }

    public int get_workspace_index (Workspace workspace) {
        return workspaces.index_of (workspace);
    }
}
