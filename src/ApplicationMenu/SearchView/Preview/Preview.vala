/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.Preview : Granite.Bin {
    public Gtk.SingleSelection selection { get; construct; }

    private Gtk.ScrolledWindow scrolled_window;
    private GenericPreview generic_preview;

    public Preview (Gtk.SingleSelection selection) {
        Object (selection: selection);
    }

    construct {
        scrolled_window = new Gtk.ScrolledWindow ();

        child = scrolled_window;

        generic_preview = new GenericPreview ();

        selection.notify["selected-item"].connect (on_selected_item_changed);
    }

    private void on_selected_item_changed () {
        var result = (Detective.Result) selection.selected_item;

        if (result == null) {
            scrolled_window.child = null;
            return;
        }

        var custom_preview = result.get_custom_preview ();
        if (custom_preview != null) {
            scrolled_window.child = custom_preview;
            return;
        }

        generic_preview.bind (result);
        scrolled_window.child = generic_preview;
    }
}
