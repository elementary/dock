/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

 public class Dock.LauncherManager : Gtk.Fixed, UnityClient {
    private static Settings settings;

    private static GLib.Once<LauncherManager> instance;
    public static unowned LauncherManager get_default () {
        return instance.once (() => { return new LauncherManager (); });
    }

    public Launcher? added_launcher { get; set; default = null; }
    public Dock.DesktopIntegration? desktop_integration { get; private set; }

    private Adw.TimedAnimation resize_animation;
    private List<Launcher> launchers; //Only used to keep track of launcher indices
    private GLib.HashTable<unowned string, App> id_to_app;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new List<Launcher> ();
        id_to_app = new GLib.HashTable<unowned string, App> (str_hash, str_equal);

        overflow = VISIBLE;
        height_request = get_launcher_size ();

        resize_animation = new Adw.TimedAnimation (
            this, 0, 0, 0,
            new Adw.CallbackAnimationTarget ((val) => {
                width_request = (int) val;
            })
        );

        settings.changed.connect ((key) => {
            if (key == "icon-size") {
                reposition_launchers ();
            }
        });

        var drop_target_file = new Gtk.DropTarget (typeof (File), COPY) {
            preload = true
        };
        add_controller (drop_target_file);

        double drop_x, drop_y;
        drop_target_file.enter.connect ((x, y) => {
            drop_x = x;
            drop_y = y;
            return COPY;
        });

        drop_target_file.notify["value"].connect (() => {
            if (drop_target_file.get_value () == null) {
                return;
            }

            if (drop_target_file.get_value ().get_object () == null) {
                return;
            }

            if (!(drop_target_file.get_value ().get_object () is File)) {
                return;
            }

            var file = (File) drop_target_file.get_value ().get_object ();
            var app_info = new DesktopAppInfo.from_filename (file.get_path ());

            if (app_info.get_id () in id_to_app) {
                id_to_app[app_info.get_id ()].pinned = true;
                drop_target_file.reject ();
                return;
            }

            var position = (int) Math.round (drop_x / get_launcher_size ());
            added_launcher = add_launcher (new DesktopAppInfo.from_filename (file.get_path ()), true, true, position);
            added_launcher.moving = true;
        });

        drop_target_file.leave.connect (() => {
            if (added_launcher != null) {
                //Without idle it crashes when the cursor is above the launcher
                Idle.add (() => {
                    remove_launcher (added_launcher);
                    added_launcher = null;
                    return Source.REMOVE;
                });
            }
        });

        Idle.add (() => {
            foreach (string app_id in settings.get_strv ("launchers")) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                add_launcher (app_info, true, false);
            }
            reposition_launchers ();

            GLib.Bus.get_proxy.begin<Dock.DesktopIntegration> (
                GLib.BusType.SESSION,
                "org.pantheon.gala",
                "/org/pantheon/gala/DesktopInterface",
                GLib.DBusProxyFlags.NONE,
                null,
                (obj, res) => {
                try {
                    desktop_integration = GLib.Bus.get_proxy.end (res);
                    desktop_integration.windows_changed.connect (sync_windows);

                    sync_windows ();
                } catch (GLib.Error e) {
                    critical (e.message);
                }
            });
        });
    }

    private void reposition_launchers () {
        height_request = get_launcher_size ();

        int index = 0;
        foreach (var launcher in launchers) {
            var position = index * get_launcher_size ();

            if (launcher.parent != this) {
                put (launcher, position, 0);
                launcher.current_pos = position;
            } else {
                launcher.animate_move (position);
            }

            index++;
        }
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }

    private Launcher add_launcher (GLib.DesktopAppInfo app_info, bool pinned = false, bool reposition = true, int index = -1) {
        var app = new App (app_info, pinned);
        var launcher = new Launcher (app);

        unowned var app_id = app_info.get_id ();
        id_to_app.insert (app_id, app);
        if (index >= 0) {
            launchers.insert (launcher, index);
        } else {
            launchers.append (launcher);
        }

        if (reposition) {
            resize_animation.easing = EASE_OUT_BACK;
            resize_animation.duration = Granite.TRANSITION_DURATION_OPEN;
            resize_animation.value_from = get_width ();
            resize_animation.value_to = launchers.length () * get_launcher_size ();
            resize_animation.play ();

            ulong reveal_cb = 0;
            reveal_cb = resize_animation.done.connect (() => {
                reposition_launchers ();
                launcher.set_revealed (true);
                resize_animation.disconnect (reveal_cb);
            });
        }

        return launcher;
    }

    public void remove_launcher (Launcher launcher, bool animate = true) {
        launchers.remove (launcher);
        id_to_app.remove (launcher.app.app_info.get_id ());

        if (animate) {
            launcher.set_revealed (false);
            launcher.revealed_done.connect (remove_finish);
        } else {
            remove_finish (launcher);
        }
    }

    private void remove_finish (Launcher launcher) {
        remove (launcher);
        reposition_launchers ();

        resize_animation.easing = EASE_IN_OUT_QUAD;
        resize_animation.duration = Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length () * get_launcher_size ();
        resize_animation.play ();
    }

    private void update_launcher_entry (string sender_name, GLib.Variant parameters, bool is_retry = false) {
        if (!is_retry) {
            // Wait to let further update requests come in to catch the case where one application
            // sends out multiple LauncherEntry-updates with different application-uris, e.g. Nautilus
            Idle.add (() => {
                update_launcher_entry (sender_name, parameters, true);
                return false;
            });

            return;
        }

        string app_uri;
        VariantIter prop_iter;
        parameters.get ("(sa{sv})", out app_uri, out prop_iter);

        var app_id = app_uri.replace ("application://", "");
        if (id_to_app[app_id] != null) {
            id_to_app[app_id].perform_unity_update (prop_iter);
        } else {
            critical ("unable to update missing launcher: %s", app_id);
        }
    }

    private void remove_launcher_entry (string sender_name) {
        var app_id = sender_name + ".desktop";
        if (id_to_app[app_id] != null) {
            id_to_app[app_id].remove_launcher_entry ();
        }
    }

    public void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] windows;
        try {
            windows = desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var app_window_list = new GLib.HashTable<App, GLib.List<AppWindow>> (direct_hash, direct_equal);
        foreach (unowned var window in windows) {
            unowned var app_id = window.properties["app-id"].get_string ();
            unowned App? app = id_to_app[app_id];
            if (app == null) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                if (app_info == null) {
                    continue;
                }

                app = add_launcher (app_info).app;
            }

            AppWindow? app_window = app.find_window (window.uid);
            if (app_window == null) {
                app_window = new AppWindow (window.uid);
            }

            app_window.update_properties (window.properties);

            unowned var window_list = app_window_list.get (app);
            if (window_list == null) {
                var new_window_list = new GLib.List<AppWindow> ();
                new_window_list.append ((owned) app_window);
                app_window_list.insert (app, (owned) new_window_list);
            } else {
                window_list.append ((owned) app_window);
            }
        }

        foreach (var app in id_to_app.get_values ()) {
            var window_list = app_window_list.take (app);
            app.update_windows ((owned) window_list);
        }

        sync_pinned ();
    }

    public void move_launcher_after (Launcher source, int target_index) {
        int source_index = launchers.index (source);

        move (source, get_launcher_size () * target_index, 0);

        bool right = source_index > target_index;

        for (int i = (right ? target_index : (source_index + 1)); i <= (right ? source_index - 1 : target_index); i++) {
            launchers.nth_data (i).animate_move (right ? (i + 1) * get_launcher_size () : (i - 1) * get_launcher_size ());
        }

        launchers.remove (source);
        launchers.insert (source, target_index);

        sync_pinned ();
    }

    public int get_index_for_launcher (Launcher launcher) {
        return launchers.index (launcher);
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};
        Launcher[] launchers_to_remove = {};

        foreach (var launcher in launchers) {
            if (launcher.app.pinned) {
                new_pinned_ids += launcher.app.app_info.get_id ();
            } else if (!launcher.app.pinned && launcher.app.windows.is_empty ()) {
                launchers_to_remove += launcher;
            }
        }

        foreach (var launcher in launchers_to_remove) {
            remove_launcher (launcher);
        }

        var settings = new Settings ("io.elementary.dock");
        settings.set_strv ("launchers", new_pinned_ids);
    }

    public void add_launcher_for_id (string app_id) {
        if (app_id in id_to_app) {
            id_to_app[app_id].pinned = true;
            return;
        }

        var app_info = new DesktopAppInfo (app_id);

        if (app_info == null) {
            warning ("App not found: %s", app_id);
            return;
        }

        add_launcher (app_info).app.pinned = true;
    }

    public void remove_launcher_by_id (string app_id) {
        if (app_id in id_to_app) {
            id_to_app[app_id].pinned = false;
        }
    }

    public string[] list_launchers () {
        return settings.get_strv ("launchers");
    }
}
