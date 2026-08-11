/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.ResultRow : Granite.Bin {
    private Gtk.Image icon;
    private Gtk.Label label;

    construct {
        icon = new Gtk.Image ();

        label = new Gtk.Label ("") {
            hexpand = true,
            xalign = 0,
            ellipsize = END
        };

        var content = new Granite.Box (HORIZONTAL, HALF) {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6,
        };
        content.append (icon);
        content.append (label);

        child = content;
    }

    public void bind (Detective.Result result) {
        icon.gicon = result.icon;
        label.label = result.title;
    }
}
