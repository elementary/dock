/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.GenericPreview : Granite.Bin {
    private Gtk.Image icon;

    private Granite.HeaderLabel label;

    construct {
        icon = new Gtk.Image () {
            pixel_size = 64
        };

        label = new Granite.HeaderLabel ("");

        var content = new Granite.Box (VERTICAL, HALF) {
            margin_top = 12,
            margin_start = 6,
            margin_end = 12,
            margin_bottom = 12
        };
        content.append (icon);
        content.append (label);

        child = content;
    }

    public void bind (Detective.Result result) {
        icon.gicon = result.icon;
        label.label = result.title;
        label.secondary_text = result.description;
    }
}
