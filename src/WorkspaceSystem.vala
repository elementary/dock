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

    public DesktopIntegration? desktop_integration { get; private set; }
    public Gee.List<Workspace> workspaces { get; private owned set; }

    private WorkspaceSystem () { }

    construct {
        workspaces = new Gee.LinkedList<Workspace> ();
    }

    public async void load () {
        try {
            desktop_integration = yield GLib.Bus.get_proxy<Dock.DesktopIntegration> (
                SESSION,
                "org.pantheon.gala",
                "/org/pantheon/gala/DesktopInterface"
            );

            yield sync_windows ();

            desktop_integration.windows_changed.connect (sync_windows);
        } catch (Error e) {
            critical ("Failed to get desktop integration: %s", e.message);
        }
    }

    public async void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] windows;
        try {
            windows = yield desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var workspace_window_list = new Gee.HashMap<int, Gee.List<WorkspaceWindow>> ();
        foreach (unowned var window in windows) {
            var workspace_index = (int) window.properties["workspace-index"].get_int32 ();

            warning ("Got windows");

            Workspace workspace;
            if (workspace_index < workspaces.size) {
                workspace = workspaces[workspace_index];
            } else {
                workspace = add_workspace (workspace_index);
            }

            WorkspaceWindow? workspace_window = workspace.find_window (window.uid);
            if (workspace_window == null) {
                workspace_window = new WorkspaceWindow (window.uid);
            }

            warning ("Updated properties");
            workspace_window.update_properties (window.properties);

            var window_list = workspace_window_list.get (workspace_index);
            if (window_list == null) {
                var new_window_list = new Gee.LinkedList<WorkspaceWindow> ();
                new_window_list.add (workspace_window);
                workspace_window_list.set (workspace_index, new_window_list);
            } else {
                window_list.add (workspace_window);
            }
        }

        foreach (var workspace in workspaces) {
            warning ("Updated windows");
            Gee.List<WorkspaceWindow>? window_list = null;
            workspace_window_list.unset (workspace.index, out window_list);
            workspace.update_windows (window_list);
        }
    }

    private Workspace add_workspace (int workspace_index) {
        warning ("Adding workspace %d", workspace_index);
        var workspace = new Workspace (workspace_index);
        workspaces.insert (workspace_index, workspace);
        workspace.removed.connect ((_workspace) => workspaces.remove (_workspace));
        workspace_added (workspace);
        return workspace;
    }
}
