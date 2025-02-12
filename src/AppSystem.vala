/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
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

    public DesktopIntegration? desktop_integration { get; private set; }

    private GLib.HashTable<unowned string, App> id_to_app;

    private AppSystem () { }

    construct {
        id_to_app = new HashTable<unowned string, App> (str_hash, str_equal);
    }

    public App? get_app (string id) {
        return id_to_app[id];
    }

    public App? get_app_for_window (DesktopIntegration.Window window) {
        foreach (unowned var app in id_to_app.get_values ()) {
            foreach (var app_window in app.windows) {
                if (app_window.uid == window.uid) {
                    return app;
                }
            }
        }

        return null;
    }

    public async void load () {
        foreach (string app_id in settings.get_strv ("launchers")) {
            var app_info = new GLib.DesktopAppInfo (app_id);
            add_app (app_info, true);
        }

        try {
            desktop_integration = yield GLib.Bus.get_proxy<Dock.DesktopIntegration> (
                SESSION,
                "org.pantheon.gala",
                "/org/pantheon/gala/DesktopInterface"
            );

            yield sync_windows ();

            desktop_integration.windows_changed.connect (sync_windows);
        } catch (Error e) {
            critical ("Failed to get desktop integration: %s", e.message);
        }
    }

    private App add_app (DesktopAppInfo app_info, bool pinned) {
        var app = new App (app_info, pinned);
        id_to_app[app_info.get_id ()] = app;
        app.removed.connect ((_app) => id_to_app.remove (_app.app_info.get_id ()));
        app_added (app);
        return app;
    }

    public async void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] windows;
        try {
            windows = yield desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var app_window_list = new Gee.HashMap<App, Gee.List<AppWindow>> ();
        foreach (unowned var window in windows) {
            unowned var app_id = window.properties["app-id"].get_string ();
            App? app = id_to_app[app_id];
            if (app == null) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                if (app_info == null) {
                    continue;
                }

                app = add_app (app_info, false);
            }

            AppWindow? app_window = app.find_window (window.uid);
            if (app_window == null) {
                app_window = new AppWindow (window.uid);
            }

            app_window.update_properties (window.properties);

            var window_list = app_window_list.get (app);
            if (window_list == null) {
                var new_window_list = new Gee.LinkedList<AppWindow> ();
                new_window_list.add (app_window);
                app_window_list.set (app, new_window_list);
            } else {
                window_list.add (app_window);
            }
        }

        foreach (var app in id_to_app.get_values ()) {
            Gee.List<AppWindow>? window_list = null;
            app_window_list.unset (app, out window_list);
            app.update_windows (window_list);
        }
    }

    public void add_app_for_id (string app_id) {
        if (app_id in id_to_app) {
            id_to_app[app_id].pinned = true;
            return;
        }

        var app_info = new DesktopAppInfo (app_id);

        if (app_info == null) {
            warning ("App not found: %s", app_id);
            return;
        }

        add_app (app_info, true);
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
