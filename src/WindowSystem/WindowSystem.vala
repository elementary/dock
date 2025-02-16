/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

 public class Dock.WindowSystem : Object {
    private static GLib.Once<WindowSystem> instance;
    public static unowned WindowSystem get_default () {
        return instance.once (() => { return new WindowSystem (); });
    }

    public signal void workspace_removed (int index);

    public DesktopIntegration? desktop_integration { get; private set; }
    public Gee.List<Window> windows { get; private owned set; }
    public int n_workspaces { get; private set; default = 0; }
    public int active_workspace { get; private set; default = 0; }

    private WindowSystem () {}

    construct {
        windows = new Gee.LinkedList<Window> ();
        load.begin ();
    }

    private async void load () {
        try {
            desktop_integration = yield GLib.Bus.get_proxy<Dock.DesktopIntegration> (
                SESSION,
                "org.pantheon.gala",
                "/org/pantheon/gala/DesktopInterface"
            );

            yield sync_windows ();
            yield sync_n_workspaces ();
            yield sync_active_workspace ();

            desktop_integration.windows_changed.connect (sync_windows);
            desktop_integration.n_workspaces_changed.connect (sync_n_workspaces);
            desktop_integration.active_workspace_changed.connect (sync_active_workspace);
            desktop_integration.workspace_removed.connect ((index) => workspace_removed (index));
        } catch (Error e) {
            critical ("Failed to get desktop integration: %s", e.message);
        }
    }

    private Window? find_window (uint64 uid) {
        return windows.first_match ((win) => {
            return win.uid == uid;
        });
    }

    private async void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] di_windows;
        try {
            di_windows = yield desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var new_windows = new Gee.LinkedList<Window> ();
        foreach (unowned var di_window in di_windows) {
            var window = find_window (di_window.uid);
            if (window == null) {
                window = new Window (di_window.uid);
            }

            window.update_properties (di_window.properties);

            new_windows.add (window);
        }

        windows = new_windows;
    }

    private async void sync_n_workspaces () requires (desktop_integration != null) {
        try {
            n_workspaces = yield desktop_integration.get_n_workspaces ();
        } catch (Error e) {
            critical (e.message);
        }
    }

    private async void sync_active_workspace () requires (desktop_integration != null) {
        try {
            active_workspace = yield desktop_integration.get_active_workspace ();
        } catch (Error e) {
            critical (e.message);
        }
    }
}
