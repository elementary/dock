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

    public async void kill () throws Error {
        var app_id = remove_desktop_suffix (app_info.get_id ());

        try {
            var object_path = "/" + app_id.replace (".", "/").replace ("-", "_");
            var parameters = new Variant (
                "(s@av@a{sv})", "quit", new Variant.array (VariantType.VARIANT, {}),
                new Variant.array (new VariantType.dict_entry (VariantType.STRING, VariantType.VARIANT), {})
            );

            var session_bus = yield Bus.get (SESSION, null);

            // DesktopAppInfo.launch_action only works for actions listed in the .desktop file
            yield session_bus.call (
                app_id, object_path, "org.freedesktop.Application",
                "ActivateAction", parameters, null, NONE, -1
            );

            return;
        } catch (Error e) {
            debug ("Failed to quit app via action, try flatpak kill: %s", e.message);
        }

        var process = new Subprocess (NONE, "flatpak", "kill", app_id);
        if (!yield process.wait_check_async (null)) {
            throw new IOError.FAILED ("Failed to kill app: %s", app_id);
        }
    }

    private string remove_desktop_suffix (string app_id) {
        if (app_id.has_suffix (".desktop")) {
            return app_id[0:app_id.length - ".desktop".length];
        }

        return app_id;
    }
}
