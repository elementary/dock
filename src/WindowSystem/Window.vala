/*
 * Copyright 2022 elementary, Inc. <https://elementary.io>
 * Copyright 2022 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Dock.Window : GLib.Object {
    public uint64 uid { get; construct set; }

    public string app_id { get; private set; default = ""; }
    public bool has_focus { get; private set; default = false; }
    public int workspace_index { get; private set; default = 0; }

    public GLib.Icon icon { get; private set; }

    public Window (uint64 uid) {
        Object (uid: uid);
    }

    public void update_properties (GLib.HashTable<string, Variant> properties) {
        if ("app-id" in properties) {
            app_id = properties["app-id"].get_string ();
        }
        if ("has-focus" in properties) {
            has_focus = properties["has-focus"].get_boolean ();
        }

        if ("workspace-index" in properties) {
            workspace_index = (int) properties["workspace-index"].get_int32 ();
        }

        var app_info = new GLib.DesktopAppInfo (app_id);
        if (app_info != null) {
            var icon = app_info.get_icon ();
            if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
                this.icon = icon;
            }
        }
    }
}
