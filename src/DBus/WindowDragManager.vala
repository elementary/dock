/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.WindowDragManager : Object {
    [DBus (name = "io.elementary.desktop.wm.WindowDragProvider")]
    private interface WindowDragProvider : Object {
        public signal void enter (uint64 window_id);
        public signal void motion (int x, int y);
        public signal void leave ();
        public signal void dropped ();
    }

    public Gtk.Window dock_window { get; construct; }

    private Window? current_window = null;
    private WorkspaceIconGroup? current_icon_group = null;

    private WindowDragProvider provider;

    public WindowDragManager (Gtk.Window dock_window) {
        Object (dock_window: dock_window);
    }

    construct {
        connect_to_dbus.begin ();
    }

    private async void connect_to_dbus () {
        try {
            provider = yield Bus.get_proxy (SESSION, "io.elementary.gala", "/io/elementary/gala");
            provider.enter.connect (on_enter);
            provider.motion.connect (on_motion);
            provider.leave.connect (on_leave);
            provider.dropped.connect (on_dropped);
        } catch (Error e) {
            warning ("Failed to connect to WindowDragProvider DBus interface: %s", e.message);
        }
    }

    private void on_enter (uint64 window_id) {
        current_window = WindowSystem.get_default ().find_window (window_id);
    }

    private void on_motion (int x, int y) {
        if (current_window == null) {
            return;
        }

        var icon_group = find_icon_group (x, y);

        if (icon_group == current_icon_group) {
            return;
        }

        if (current_icon_group != null) {
            current_icon_group.window_left ();
        }

        current_icon_group = icon_group;

        if (current_icon_group != null) {
            current_icon_group.window_entered (current_window);
        }
    }

    private WorkspaceIconGroup? find_icon_group (int x, int y) {
        double root_x, root_y;
        dock_window.get_surface_transform (out root_x, out root_y);

        var widget = dock_window.pick (x - root_x, y - root_y, DEFAULT);

        while (!(widget is WorkspaceIconGroup) && widget != null) {
            widget = widget.get_parent ();
        }

        if (widget is WorkspaceIconGroup) {
            return (WorkspaceIconGroup) widget;
        }

        return null;
    }

    private void on_leave () {
        if (current_icon_group != null) {
            current_icon_group.window_left ();
            current_icon_group = null;
        }

        current_window = null;
    }

    private void on_dropped () {
        if (current_icon_group != null && current_window != null &&
            current_icon_group.workspace.index != current_window.workspace_index
        ) {
            WindowSystem.get_default ().move_window_to_workspace.begin (
                current_window.uid, current_icon_group.workspace.index
            );
        }
    }
}
