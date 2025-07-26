/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.BackgroundApp : Object {
    public DesktopAppInfo app_info { get; construct; }
    public Icon icon { get { return app_info.get_icon (); } }
    public string? instance { get; construct; }
    public string? message { get; construct; }

    public BackgroundApp (DesktopAppInfo app_info, string? instance, string? message) {
        Object (app_info: app_info, instance: instance, message: message);
    }

    public void kill () {
        if (instance == null) {
            warning ("No instance to kill");
            return;
        }

        try {
            var app_id = app_info.get_id ().replace (".desktop", "");
            Process.spawn_command_line_async ("flatpak kill %s".printf (app_id));
        } catch (Error e) {
            warning ("Failed to kill instance: %s", e.message);
        }
    }
}
