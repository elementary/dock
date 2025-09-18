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

    private GLib.HashTable<unowned string, App> id_to_app;

    private AppSystem () { }

    construct {
        id_to_app = new HashTable<unowned string, App> (str_hash, str_equal);
    }

    public App? get_app (string id) {
        return id_to_app[id];
    }

    public async void load () {
        foreach (unowned var app_id in settings.get_strv ("launchers")) {
            add_app (new GLib.DesktopAppInfo (app_id), true);
        }

        yield sync_windows ();
        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
    }

    private App add_app (DesktopAppInfo app_info, bool pinned) {
        var app = new App (app_info, pinned);
        id_to_app[app_info.get_id ()] = app;
        app.removed.connect ((app) => id_to_app.remove (app.app_info.get_id ()));
        app_added (app);
        return app;
    }

    public async void sync_windows () {
        var windows = WindowSystem.get_default ().windows;

        var app_window_list = new GLib.HashTable<App, GLib.GenericArray<Window>> (direct_hash, direct_equal);
        foreach (var window in windows) {
            App? app = id_to_app[window.app_id];
            if (app == null) {
                var app_info = new GLib.DesktopAppInfo (window.app_id);
                if (app_info == null) {
                    continue;
                }

                app = add_app (app_info, false);
            }

            var window_list = app_window_list.get (app);
            if (window_list == null) {
                var new_window_list = new GLib.GenericArray<Window> ();
                new_window_list.add (window);
                app_window_list.set (app, new_window_list);
            } else {
                window_list.add (window);
            }
        }

        foreach (var app in id_to_app.get_values ()) {
            GLib.GenericArray<Window>? window_list = null;
            app_window_list.steal_extended (app, null, out window_list);
            app.update_windows (window_list);
        }
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
