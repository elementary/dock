/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    // First %s is the app id second %s the action name
    public const string LAUNCHER_ACTION_TEMPLATE = "%s.%s";
    // %s is the app id
    public const string LAUNCHER_PINNED_ACTION_TEMPLATE = "%s-pinned";
    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private static Gtk.CssProvider css_provider;
    private static Settings settings;

    private Gtk.Box box;
    private Dock.DesktopIntegration desktop_integration;
    private GLib.HashTable<unowned string, Dock.Launcher> app_to_launcher;

    class construct {
        set_css_name ("dock");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/MainWindow.css");

        settings = new Settings ("io.elementary.dock");
    }

    construct {
        app_to_launcher = new GLib.HashTable<unowned string, Dock.Launcher> (str_hash, str_equal);
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var empty_title = new Gtk.Label ("") {
            visible = false
        };

        child = box;
        overflow = Gtk.Overflow.VISIBLE;
        resizable = false;
        set_titlebar (empty_title);

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        box.add_controller (drop_target_launcher);

        GLib.Bus.get_proxy.begin<Dock.DesktopIntegration> (
            GLib.BusType.SESSION,
            "org.pantheon.gala",
            "/org/pantheon/gala/DesktopInterface",
            GLib.DBusProxyFlags.NONE,
            null,
            (obj, res) => {
            try {
                desktop_integration = GLib.Bus.get_proxy.end (res);
                desktop_integration.windows_changed.connect (() => {
                    sync_windows ();
                });

                sync_windows ();
            } catch (GLib.Error e) {
                critical (e.message);
            }
        });

        foreach (string app_id in settings.get_strv ("launchers")) {
            var app_info = new GLib.DesktopAppInfo (app_id);
            unowned var launcher = add_launcher (app_info);
            launcher.pinned = true;
        }
    }

    private unowned Launcher add_launcher (GLib.DesktopAppInfo app_info) {
        var launcher = new Launcher (app_info);
        unowned var app_id = app_info.get_id ();
        app_to_launcher.insert (app_id, launcher);
        box.append (launcher);

        var pinned_action = new SimpleAction.stateful (
            LAUNCHER_PINNED_ACTION_TEMPLATE.printf (app_id),
            null,
            new Variant.boolean (launcher.pinned)
        );
        launcher.notify["pinned"].connect (() => pinned_action.set_state (launcher.pinned));
        pinned_action.change_state.connect ((new_state) => launcher.pinned = (bool) new_state);
        add_action (pinned_action);

        foreach (var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (LAUNCHER_ACTION_TEMPLATE.printf (app_id, action), null);
            simple_action.activate.connect (() => launcher.launch (action));
            add_action (simple_action);
        }

        return app_to_launcher[app_id];
    }

    private void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] windows;
        try {
            windows = desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var launcher_window_list = new GLib.HashTable<Launcher, GLib.List<AppWindow>> (direct_hash, direct_equal);
        foreach (unowned var window in windows) {
            unowned var app_id = window.properties["app-id"].get_string ();
            unowned Launcher? launcher = app_to_launcher.get (app_id);
            if (launcher == null) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                if (app_info == null) {
                    continue;
                }

                launcher = add_launcher (app_info);
            }

            AppWindow? app_window = launcher.find_window (window.uid);
            if (app_window == null) {
                app_window = new AppWindow (window.uid);
            }

            unowned var window_list = launcher_window_list.get (launcher);
            if (window_list == null) {
                var new_window_list = new GLib.List<AppWindow> ();
                new_window_list.append ((owned) app_window);
                launcher_window_list.insert (launcher, (owned) new_window_list);
            } else {
                window_list.append ((owned) app_window);
            }
        }

        app_to_launcher.foreach_remove ((app_id, launcher) => {
            var window_list = launcher_window_list.take (launcher);
            launcher.update_windows ((owned) window_list);
            if (launcher.windows.is_empty () && !launcher.pinned) {
                remove_launcher (launcher, false);
                return true;
            }

            return false;
        });
    }

    public void move_launcher_after (Launcher source, Launcher? target) {
        var before_source = source.get_prev_sibling ();

        box.reorder_child_after (source, target);

        /*
         * should_animate toggles to true once either the launcher before the one
         * that was moved is reached or once the one that was moved is reached
         * and goes false again once the other one is reached. While true
         * all launchers that are iterated over are animated to move in the appropriate
         * direction.
         */
        bool should_animate = false;
        Gtk.DirectionType dir = UP; // UP is an invalid placeholder value

        // source was the first launcher in the box so we start animating right away
        if (before_source == null) {
            should_animate = true;
            dir = LEFT;
        }

        Launcher child = (Launcher) box.get_first_child ();
        while (child != null) {
            if (child == source) {
                should_animate = !should_animate;
                if (should_animate) {
                    dir = RIGHT;
                }
            }

            if (should_animate && child != source) {
                child.animate_move (dir);
            }

            if (child == before_source) {
                should_animate = !should_animate;
                if (should_animate) {
                    dir = LEFT;
                }
            }

            child = (Launcher) child.get_next_sibling ();
        }

        sync_pinned ();
    }

    public void remove_launcher (Launcher launcher, bool from_map = true) {
        foreach (var action in list_actions ()) {
            if (action.has_prefix (launcher.app_info.get_id ())) {
                remove_action (action);
            }
        }
        box.remove (launcher);

        if (from_map) {
            app_to_launcher.remove (launcher.app_info.get_id ());
        }
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        unowned Launcher child = (Launcher) box.get_first_child ();
        while (child != null) {
            unowned var current_child = child;
            child = (Launcher) child.get_next_sibling ();

            if (current_child.pinned) {
                new_pinned_ids += current_child.app_info.get_id ();
            } else if (!current_child.pinned && current_child.windows.is_empty ()) {
                remove_launcher (current_child);
            }
        }


        var settings = new Settings ("io.elementary.dock");
        settings.set_strv ("launchers", new_pinned_ids);
    }
}
