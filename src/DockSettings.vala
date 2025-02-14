/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.DockSettings : GLib.Object {
    private static GLib.Once<DockSettings> instance;
    public static unowned DockSettings get_default () {
        return instance.once (() => { return new DockSettings (); });
    }

    private GLib.Settings dock_settings;

    public int icon_size { get; set; }
    public string[] launchers { get; set; }

    construct {
        dock_settings = new GLib.Settings ("io.elementary.dock");

        dock_settings.bind ("icon-size", this, "icon-size", DEFAULT);
        dock_settings.bind ("launchers", this, "launchers", DEFAULT);
    }
}
