/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    private static Gtk.CssProvider css_provider;

    private Settings settings;
    private Gtk.Box box;
    private Dock.DesktopIntegration desktop_integration;
    private GLib.HashTable<unowned string, Dock.Launcher> app_to_launcher;

    class construct {
        set_css_name ("dock");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/MainWindow.css");
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
        decorated = false;
        set_titlebar (empty_title);

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        box.add_controller (drop_target_launcher);

        settings = new Settings ("io.elementary.dock");

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
            if (launcher.windows.is_empty ()) {
                if (!launcher.pinned) {
                    launcher.unparent ();
                    return true;
                }
            }

            return false;
        });
    }

    public void remove_launcher (Launcher launcher) {
        if (launcher.windows.is_empty ()) {
            box.remove (launcher);
            app_to_launcher.remove (launcher.app_info.get_id ());
        }

        if (launcher.pinned) {
            launcher.pinned = false;

            var old_pinned_ids = settings.get_strv ("launchers");
            string[] new_pinned_ids = {};

            var to_remove_id = launcher.app_info.get_id ();
            foreach (string app_id in old_pinned_ids) {
                if (app_id != to_remove_id) {
                    new_pinned_ids += app_id;
                }
            }

            settings.set_strv ("launchers", new_pinned_ids);
        }
    }

    public void move_launcher_after (Launcher source, Launcher? target) {
        var before_source = source.get_prev_sibling ();

        box.reorder_child_after (source, target);

        string[] new_pinned_ids = {};
        bool add = false;
        Gtk.DirectionType dir = UP; // UP is an invalid value in this case

        if (before_source == null) {
            add = true;
            dir = LEFT;
        }

        Launcher child = (Launcher) box.get_first_child ();
        while (child != null) {
            if (child.pinned) {
                new_pinned_ids += child.app_info.get_id ();
            }

            if (child == source) {
                add = !add;
                if (add) {
                    dir = RIGHT;
                }
            }

            if (add && child != source) {
                child.animate_move (dir);
            }

            if (child == before_source) {
                add = !add;
                if (add) {
                    dir = LEFT;
                }
            }

            child = (Launcher) child.get_next_sibling ();
        }

        settings.set_strv ("launchers", new_pinned_ids);
    }
}
