/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.AppCache : Object {
    private const int DEFAULT_TIMEOUT_SECONDS = 3;

    private ListStore _apps;
    public ListModel apps { get { return _apps; } }

    private HashTable<unowned string, DesktopAppInfo> id_to_app;

    private AppInfoMonitor app_info_monitor;

    private uint queued_update_id = 0;

    construct {
        _apps = new ListStore (typeof (DesktopAppInfo));
        id_to_app = new HashTable<unowned string, DesktopAppInfo> (str_hash, str_equal);

        app_info_monitor = AppInfoMonitor.@get ();
        app_info_monitor.changed.connect (queue_cache_update);

        rebuild_cache.begin ();
    }

    private void queue_cache_update () {
        if (queued_update_id != 0) {
            return;
        }

        queued_update_id = Timeout.add_seconds (DEFAULT_TIMEOUT_SECONDS, () => {
            rebuild_cache.begin ();;
            return Source.REMOVE;
        });
    }

    private async void rebuild_cache () {
        SourceFunc callback = rebuild_cache.callback;

        new Thread<void> ("rebuild_cache", () => {
            lock (id_to_app) {
                id_to_app.remove_all ();

                var app_infos = AppInfo.get_all ();

                foreach (unowned var app in app_infos) {
                    id_to_app[app.get_id ()] = (DesktopAppInfo) app;
                }
            }

            Idle.add ((owned) callback);
        });

        yield;

        _apps.splice (0, _apps.n_items, id_to_app.get_values_as_ptr_array ().data);
        queued_update_id = 0;
    }

    public DesktopAppInfo get_app_by_id (string id) {
        return id_to_app[id];
    }
}
