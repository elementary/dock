/*
 * Copyright 2022 elementary, Inc. <https://elementary.io>
 * Copyright 2022 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name="org.pantheon.gala.DesktopIntegration")]
public interface Dock.DesktopIntegration : GLib.Object {
    public struct RunningApplication {
        string app_id;
        GLib.HashTable<string, Variant> details;
    }

    public struct Window {
        uint64 uid;
        GLib.HashTable<string, Variant> properties;
    }

    public abstract uint version { get; default = 1; }

    public signal void running_applications_changed ();
    public signal void windows_changed ();

    public abstract RunningApplication[] get_running_applications () throws GLib.DBusError, GLib.IOError;
    public abstract Window[] get_windows () throws GLib.DBusError, GLib.IOError;
}
