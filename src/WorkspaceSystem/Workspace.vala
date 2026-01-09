/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Workspace : GLib.Object {
    private ListStore store;
    public ListModel windows { get { return store; } }
    public int index { get; set; }
    public bool is_active_workspace { get; private set; }

    construct {
        store = new ListStore (typeof (Window));
    }

    public void update_windows (GLib.GenericArray<Window> new_windows) {
        store.splice (0, store.get_n_items (), new_windows.data);
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
}
