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

    private ListStore apps_store;
    public ListModel apps { get { return apps_store; } }

    private GLib.HashTable<unowned string, App> id_to_app;

    private AppSystem () { }

    construct {
        apps_store = new ListStore (typeof (App));
        apps_store.items_changed.connect (save_pinned);

        id_to_app = new HashTable<unowned string, App> (str_hash, str_equal);
    }

    public App? get_app_by_id (string id) {
        if (!(id in id_to_app)) {
            var app_info = new DesktopAppInfo (id);

            if (app_info == null) {
                return null;
            }

            var app = new App (app_info);
            app.notify["running"].connect (check_app);
            app.notify["pinned"].connect (check_app);
            app.notify["pinned"].connect (save_pinned);

            id_to_app[app_info.get_id ()] = app;
        }

        return id_to_app[id];
    }

    private void check_app (Object obj, ParamSpec pspec) {
        var app = (App) obj;

        uint pos;
        var exists = apps_store.find (app, out pos);

        if ((app.pinned || app.running) && !exists) {
            apps_store.append (app);
        } else if ((!app.pinned && !app.running) && exists) {
            apps_store.remove (pos);
        }
    }

    private void save_pinned () {
        string[] new_pinned_ids = {};

        for (uint i = 0; i < apps_store.get_n_items (); i++) {
            var app = (App) apps_store.get_item (i);
            if (app.pinned) {
                new_pinned_ids += app.app_info.get_id ();
            }
        }

        settings.set_strv ("launchers", new_pinned_ids);
    }

    public void reorder_app (App app, uint new_index) {
        uint pos;
        if (!apps_store.find (app, out pos)) {
            warning ("Tried to reorder an app that is not in the store");
            return;
        }

        apps_store.remove (pos);
        apps_store.insert (new_index, app);
    }

    public async void load () {
        foreach (string app_id in settings.get_strv ("launchers")) {
            var app = get_app_by_id (app_id);
            if (app == null) {
                continue;
            }
            app.pinned = true;
        }

        yield sync_windows ();
        WindowSystem.get_default ().notify["windows"].connect (sync_windows);
    }

    public async void sync_windows () {
        var windows = WindowSystem.get_default ().windows;

        var app_window_list = new GLib.HashTable<App, GLib.GenericArray<Window>> (direct_hash, direct_equal);
        foreach (var window in windows) {
            var app = get_app_by_id (window.app_id);
            if (app == null) {
                continue;
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

    public void add_app_for_id (string app_id) {
        var app = get_app_by_id (app_id);

        if (app != null) {
            app.pinned = true;
        }
    }

    public void remove_app_by_id (string app_id) {
        var app = get_app_by_id (app_id);

        if (app != null) {
            app.pinned = false;
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
        var app = get_app_by_id (app_id);
        if (app != null) {
            app.perform_unity_update (prop_iter);
        } else {
            critical ("unable to update missing launcher: %s", app_id);
        }
    }

    private void remove_launcher_entry (string sender_name) {
        var app_id = sender_name + ".desktop";
        var app = get_app_by_id (app_id);
        if (app != null) {
            app.remove_launcher_entry ();
        }
    }
}
