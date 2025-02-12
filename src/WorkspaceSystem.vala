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
    public GLib.List<Workspace> workspaces { get; private owned set; }

    private WorkspaceSystem () { }

    construct {
        workspaces = new GLib.List<Workspace> ();
    }

    public async void load () {
        try {
            desktop_integration = yield GLib.Bus.get_proxy<Dock.DesktopIntegration> (
                SESSION,
                "org.pantheon.gala",
                "/org/pantheon/gala/DesktopInterface"
            );

            yield sync_workspaces ();

            desktop_integration.workspaces_changed.connect (sync_workspaces);
        } catch (Error e) {
            critical ("Failed to get desktop integration: %s", e.message);
        }
    }

    public async void sync_workspaces () requires (desktop_integration != null) {
        DesktopIntegration.Workspace[] di_workspaces;
        try {
            di_workspaces = yield desktop_integration.get_workspaces ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        
        //  var app_window_list = new Gee.HashMap<App, Gee.List<AppWindow>> ();
        for (var i = 0; i < di_workspaces.length; i++) {
            var di_workspace = di_workspaces[i];

            if (i >= workspaces.length ()) {
                add_workspace (di_workspace);
                continue;
            }

            workspaces.nth_data (i).update (di_workspace);
        }

        if (di_workspaces.length < workspaces.length ()) {
            (unowned Workspace)[] to_remove = {};
            for (var i = di_workspaces.length; i < workspaces.length (); i++) {
                to_remove += workspaces.nth_data (i);
            }

            for (var i = 0; i < to_remove.length; i++) {
                unowned var workspace = to_remove[i];
                workspace.remove ();
                workspaces.remove (workspace);
            }
        }
    }


    private void add_workspace (DesktopIntegration.Workspace di_workspace) {
        var workspace = new Workspace (di_workspace);
        workspaces.append (workspace);
        workspace_added (workspace);
    }
}
