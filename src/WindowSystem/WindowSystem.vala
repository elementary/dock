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
    public GLib.GenericArray<Window> windows { get; private owned set; }
    public int active_workspace { get; private set; default = 0; }

    private WindowSystem () {}

    construct {
        windows = new GLib.GenericArray<Window> ();
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
            yield sync_active_workspace ();

            desktop_integration.windows_changed.connect (sync_windows);
            desktop_integration.active_workspace_changed.connect (sync_active_workspace);
            desktop_integration.workspace_removed.connect ((index) => workspace_removed (index));
        } catch (Error e) {
            critical ("Failed to get desktop integration: %s", e.message);
        }
    }

    public Window? find_window (uint64 uid) {
        uint index;
        if (windows.find_custom (uid, (win, uid) => {
            return win.uid == (uint64) uid;
        }, out index)) {
            return windows[index];
        }

        return null;
    }

    private async void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] di_windows;
        try {
            di_windows = yield desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var new_windows = new GLib.GenericArray<Window> ();
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

    private async void sync_active_workspace () requires (desktop_integration != null) {
        try {
            active_workspace = yield desktop_integration.get_active_workspace ();
        } catch (Error e) {
            critical (e.message);
        }
    }

    public async void move_window_to_workspace (uint64 window, int workspace) requires (desktop_integration != null) {
        try {
            yield desktop_integration.move_window_to_workspace (window, workspace);
        } catch (Error e) {
            critical ("Failed to move window to workspace: %s", e.message);
        }
    }
}
