/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Workspace : GLib.Object {
    public signal void removed ();

    public Gee.List<Window> windows { get; owned set; }
    public int index { get; set; }
    public bool is_active_workspace { get; private set; }

    construct {
        windows = new Gee.LinkedList<Window> ();
    }

    public void remove () {
        removed ();
    }

    public void update_active_workspace () {
        is_active_workspace = index == WindowSystem.get_default ().active_workspace;
    }

    public void activate () {
        WindowSystem.get_default ().desktop_integration.activate_workspace.begin (index);
    }
}
