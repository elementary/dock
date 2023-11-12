/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    private static Gtk.CssProvider css_provider;
    private static Settings settings;

    class construct {
        set_css_name ("dock");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/MainWindow.css");

        settings = new Settings ("io.elementary.dock");
    }

    construct {
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var launcher_manager = LauncherManager.get_default ();

        var flow_box = new Gtk.FlowBox () {
            max_children_per_line = 1,
            orientation = VERTICAL
        };
        flow_box.bind_model (launcher_manager.launchers, (obj) => {
            return (Launcher) obj;
        });

        var empty_title = new Gtk.Label ("") {
            visible = false
        };

        child = flow_box;
        overflow = Gtk.Overflow.VISIBLE;
        resizable = false;
        set_titlebar (empty_title);
        insert_action_group (LauncherManager.ACTION_GROUP_PREFIX, launcher_manager.action_group);

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        flow_box.add_controller (drop_target_launcher);

        flow_box.child_activated.connect ((child) => ((Launcher) child).launch ());
    }
}
