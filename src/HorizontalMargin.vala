/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

public class HorizontalMargin : Gtk.Widget {
    private static GLib.List<unowned HorizontalMargin> instances = new GLib.List<unowned HorizontalMargin> ();

    class construct {
        set_css_name ("horizontal-margin");
    }

    construct {
        instances.append (this);
    }

    ~HorizontalMargin () {
        instances.remove (this);
    }

    public new static int get_size () {
        foreach (var instance in instances) {
            if (instance.get_realized ()) {
                return instance.get_width ();
            }
        }

        return 0;
    }
}
