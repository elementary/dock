/*
 * Copyright 2022 elementary, Inc. <https://elementary.io>
 * Copyright 2022 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Dock.AppWindow : GLib.Object {
    public uint64 uid { get; construct set; }

    public AppWindow (uint64 uid) {
        Object (uid: uid);
    }
}
