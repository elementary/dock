/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "org.freedesktop.background.Monitor")]
public interface Freedesktop.BackgroundMonitor : DBusProxy {
    public abstract HashTable<string, Variant>[] background_apps { owned get; }
}

public class Dock.BackgroundMonitor : Object {
    public ListStore background_apps { get; construct; }

    private Freedesktop.BackgroundMonitor? proxy;

    construct {
        background_apps = new ListStore (typeof (BackgroundApp));
    }

    public void load () {
        Bus.watch_name (SESSION, "org.freedesktop.background.Monitor", NONE, () => on_name_appeared.begin (), () => proxy = null);
    }

    private async void on_name_appeared () {
        try {
            proxy = yield Bus.get_proxy (
                SESSION,
                "org.freedesktop.background.Monitor",
                "/org/freedesktop/background/monitor",
                GET_INVALIDATED_PROPERTIES
            );
            proxy.g_properties_changed.connect (update_background_apps);

            update_background_apps ();
        } catch (Error e) {
            warning ("Failed to get background monitor proxy: %s", e.message);
        }
    }

    private void update_background_apps () {
        BackgroundApp[] apps = {};

        foreach (var table in proxy.background_apps) {
            DesktopAppInfo? app_info = null;
            if ("app_id" in table) {
                app_info = new DesktopAppInfo ((string) table["app_id"] + ".desktop");
            }

            if (app_info == null) {
                continue;
            }

            string? instance = null;
            if ("instance" in table) {
                instance = (string) table["instance"];
            }

            string? message = null;
            if ("message" in table) {
                message = (string) table["message"];
            }

            apps += new BackgroundApp (app_info, instance, message);
        }

        background_apps.splice (0, background_apps.n_items, apps);
    }
}
