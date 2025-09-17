/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class BottomMargin : Gtk.Widget {
    private static GLib.List<unowned BottomMargin> instances = new GLib.List<unowned BottomMargin> ();

    class construct {
        set_css_name ("bottom-margin");
    }

    construct {
        instances.append (this);
    }

    ~BottomMargin () {
        instances.remove (this);
    }

    public new static int get_size () {
        foreach (var instance in instances) {
            if (instance.get_realized ()) {
                return instance.get_height ();
            }
        }

        return 0;
    }
}
