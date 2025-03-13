/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.AppSystem : Object, UnityClient {
    private static Settings settings;
    private static GLib.Once<AppSystem> instance;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    public static unowned AppSystem get_default () {
        return instance.once (() => { return new AppSystem (); });
    }

    public signal void app_added (App app);

    public AppCache app_cache { get; construct; }

    private GLib.HashTable<unowned string, App> id_to_app; // This only stores apps that are visible in the dock

    private AppSystem () { }

    construct {
        app_cache = new AppCache ();
        id_to_app = new HashTable<unowned string, App> (str_hash, str_equal);
    }

    public App? get_app (string id) {
        return id_to_app[id];
    }

    public async void load () {
        foreach (string app_id in settings.get_strv ("launchers")) {
            add_app (app_id, true);
        }

        yield sync_windows ();
        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
    }

    private App? add_app (string id, bool pinned) {
        var app = app_cache.get_app (id);
        if (app == null) {
            warning ("App %s not found.", id);
            return null;
        }

        app.pinned = pinned;
        id_to_app[id] = app;
        app.removed.connect ((_app) => id_to_app.remove (_app.app_info.get_id ()));
        app_added (app);
        return app;
    }

    public async void sync_windows () {
        var windows = WindowSystem.get_default ().windows;

        var app_window_list = new Gee.HashMap<App, Gee.List<Window>> ();
        foreach (var window in windows) {
            App? app = id_to_app[window.app_id];
            if (app == null) {
                app = add_app (window.app_id, false);

                if (app == null) {
                    continue;
                }
            }

            var window_list = app_window_list.get (app);
            if (window_list == null) {
                var new_window_list = new Gee.LinkedList<Window> ();
                new_window_list.add (window);
                app_window_list.set (app, new_window_list);
            } else {
                window_list.add (window);
            }
        }

        foreach (var app in id_to_app.get_values ()) {
            Gee.List<Window>? window_list = null;
            app_window_list.unset (app, out window_list);
            app.update_windows (window_list);
        }
    }

    public void add_app_for_id (string app_id) {
        if (app_id in id_to_app) {
            id_to_app[app_id].pinned = true;
            return;
        }

        add_app (app_id, true);
    }

    public void remove_app_by_id (string app_id) {
        if (app_id in id_to_app) {
            id_to_app[app_id].pinned = false;
        }
    }

    public string[] list_launchers () {
        return settings.get_strv ("launchers");
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
}
