/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.AppCache : GLib.Object {
    public ListStore apps { get; construct; }

    private const int DEFAULT_TIMEOUT_SECONDS = 3;

    private GLib.HashTable<unowned string, App> id_to_app;

    private GLib.AppInfoMonitor app_info_monitor;

    private uint queued_update_id = 0;

    construct {
        apps = new ListStore (typeof (App));

        id_to_app = new GLib.HashTable<unowned string, App> (str_hash, str_equal);

        app_info_monitor = GLib.AppInfoMonitor.@get ();
        app_info_monitor.changed.connect (queue_cache_update);

        rebuild_cache.begin ();
    }

    private void queue_cache_update () {
        if (queued_update_id != 0) {
            GLib.Source.remove (queued_update_id);
        }

        queued_update_id = GLib.Timeout.add_seconds (DEFAULT_TIMEOUT_SECONDS, () => {
            rebuild_cache.begin ((obj, res) => {
                rebuild_cache.end (res);
                queued_update_id = 0;
            });

            return GLib.Source.REMOVE;
        });
    }

    private async void rebuild_cache () {
        new Thread<void> ("rebuild_cache", () => {
            lock (id_to_app) {
                var to_remove = id_to_app.get_keys ();

                var app_infos = GLib.AppInfo.get_all ();

                foreach (unowned AppInfo app_info in app_infos) {
                    if (!(app_info is DesktopAppInfo)) {
                        continue;
                    }

                    var desktop_app_info = (DesktopAppInfo) app_info;

                    if (!desktop_app_info.should_show ()) {
                        continue;
                    }

                    unowned var id = app_info.get_id ();
                    if (id in id_to_app) {
                        to_remove.remove (id);
                        continue;
                    }

                    id_to_app[id] = new App (desktop_app_info, false);
                }

                foreach (var id in to_remove) {
                    id_to_app.remove (id);
                }
            }

            Idle.add (rebuild_cache.callback);
        });

        yield;

        apps.splice (0, apps.n_items, id_to_app.get_values_as_ptr_array ().data);
    }
}
