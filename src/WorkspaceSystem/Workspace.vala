/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Workspace : GLib.Object {
    public signal void reordered (int new_index);
    public signal void removed ();

    public GLib.GenericArray<Window> windows { get; owned set; }
    public int index { get; set; }
    public bool is_active_workspace { get; private set; }

    construct {
        windows = new GLib.GenericArray<Window> ();
    }

    public void remove () {
        removed ();
    }

    public void update_active_workspace () {
        is_active_workspace = index == WindowSystem.get_default ().active_workspace;
    }

    public void activate () {
        if (is_active_workspace) {
            GalaDBus.open_multitaksing_view ();
        } else {
            WindowSystem.get_default ().desktop_integration.activate_workspace.begin (index);
        }
    }

    public void reorder (int new_index) {
        reordered (new_index);
        WindowSystem.get_default ().desktop_integration.reorder_workspace.begin (index, new_index);
    }
}
