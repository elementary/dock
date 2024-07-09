/*
 * Copyright 2022 elementary, Inc. <https://elementary.io>
 * Copyright 2022 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Dock.AppWindow : GLib.Object {
    public uint64 uid { get; construct set; }

    public bool has_focus { get; private set; default = false; }
    public bool on_active_workspace { get; private set; default = false; }

    public AppWindow (uint64 uid) {
        Object (uid: uid);
    }

    public void update_properties (GLib.HashTable<string, Variant> properties) {
        if ("has-focus" in properties) {
            has_focus = (bool) properties["has-focus"];
        }

        if ("on-active-workspace" in properties) {
            on_active_workspace = (bool) properties["on-active-workspace"];
        }
    }
}
