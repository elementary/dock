/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.AppInfo : GLib.Object {
    private const string[] NULL_ACTIONS = {};
    private GLib.Icon fallback_icon = new GLib.ThemedIcon ("application-default-icon");

    public GLib.DesktopAppInfo? desktop_app_info { get; construct; }

    private string _fake_id = "Unknown";
    public string? fake_id {
        private get {
            return _fake_id;
        }
        set {
            _fake_id = value ?? "Unknown";
        }
    }

    private string _fake_name = "Unknown";
    public string? fake_name {
        private get {
            return _fake_name;
        }
        set {
            _fake_name = value ?? "Unknown";
        }
    }

    public AppInfo (GLib.DesktopAppInfo? desktop_app_info) {
        Object (desktop_app_info: desktop_app_info);
    }

    public unowned string get_id () {
        if (desktop_app_info == null) {
            return fake_id;
        }

        return desktop_app_info.get_id ();
    }

    public unowned string get_display_name () {
        if (desktop_app_info == null) {
            return fake_name;
        }

        return desktop_app_info.get_display_name ();
    }

    public unowned GLib.Icon get_icon () {
        if (desktop_app_info == null) {
            return fallback_icon;
        }

        return desktop_app_info.get_icon () ?? fallback_icon;
    }

    public bool get_boolean (string key) {
        if (desktop_app_info == null) {
            return false;
        }

        return desktop_app_info.get_boolean (key);
    }

    public string get_string (string key) {
        if (desktop_app_info == null) {
            return "";
        }

        return desktop_app_info.get_string (key);
    }

    public unowned string[] list_actions () {
        if (desktop_app_info == null) {
            return NULL_ACTIONS;
        }

        return desktop_app_info.list_actions ();
    }

    public string get_action_name (string action_name) {
        if (desktop_app_info == null) {
            return "Something went wrong if you see this";
        }

        return desktop_app_info.get_action_name (action_name);
    }

    public void launch_action (string action_name, GLib.AppLaunchContext launch_context) {
        if (desktop_app_info == null) {
            return;
        }

        desktop_app_info.launch_action (action_name, launch_context);
    }

    public bool launch (GLib.List<GLib.File>? files, GLib.AppLaunchContext? context) throws GLib.Error {
        if (desktop_app_info == null) {
            return false;
        }

        return desktop_app_info.launch (files, context);
    }
}
