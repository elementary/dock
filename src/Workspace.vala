/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Workspace : GLib.Object {
    public signal void removed ();
    public signal void windows_changed ();

    public Gee.List<Window> windows { get; private owned set; }

    construct {
        windows = new Gee.LinkedList<Window> ();
    }

    public void update_windows (Gee.List<Window>? new_windows) {
        if (new_windows == null) {
            windows = new Gee.LinkedList<Window> ();
        } else {
            windows = new_windows;
        }

        windows_changed ();
    }

    public void remove () {
        removed ();
    }

    public void activate () {
        var index = WorkspaceSystem.get_default ().get_workspace_index (this);
        WindowSystem.get_default ().desktop_integration.activate_workspace.begin (index);
    }
}
