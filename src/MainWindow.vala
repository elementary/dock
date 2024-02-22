/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    class construct {
        set_css_name ("dock");
    }

    construct {
        var launcher_manager = LauncherManager.get_default ();

        child = launcher_manager;
        overflow = VISIBLE;
        resizable = false;
        titlebar = new Gtk.Label ("") { visible = false };

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        launcher_manager.add_controller (drop_target_launcher);
    }
}
