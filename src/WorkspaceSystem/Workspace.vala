/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Workspace : GLib.Object {
    public signal void removed ();

    public Gee.List<Window> windows { get; owned set; }
    public bool is_last_workspace { get; set; }

    construct {
        windows = new Gee.LinkedList<Window> ();
    }

    public void remove () {
        removed ();
    }

    public void activate () {
        var index = WorkspaceSystem.get_default ().get_workspace_index (this);
        WindowSystem.get_default ().desktop_integration.activate_workspace.begin (index);
    }
}
