/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.Button {
    public GLib.DesktopAppInfo app_info { get; construct; }
    public bool pinned { get; set; }

    public GLib.List<AppWindow> windows { get; private owned set; }

    private static Gtk.CssProvider css_provider;

    public Launcher (GLib.DesktopAppInfo app_info) {
        Object (app_info: app_info);
    }

    class construct {
        set_css_name ("launcher");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/Launcher.css");
    }

    construct {
        windows = new GLib.List<AppWindow> ();
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var image = new Gtk.Image () {
            gicon = app_info.get_icon ()
        };
        image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        // Needed to work around DnD bug where it
        // would stop working once the button got clicked
        var box = new Gtk.Box (VERTICAL, 0);
        box.append (image);

        child = box;
        tooltip_text = app_info.get_display_name ();

        var drag_source = new Gtk.DragSource () {
            actions = MOVE
        };
        box.add_controller (drag_source);

        drag_source.prepare.connect (() => {
            var val = Value (typeof (Launcher));
            val.set_object (this);
            var content_provider = new Gdk.ContentProvider.for_value (val);
            return content_provider;
        });

        drag_source.drag_cancel.connect ((drag, reason) => {
            if (reason == NO_TARGET) {
                ((MainWindow)get_root ()).remove_launcher (this);
            }
        });

        var drop_target = new Gtk.DropTarget (typeof (Launcher), MOVE);
        box.add_controller (drop_target);
        drop_target.drop.connect (on_drop);

        clicked.connect (() => {
            try {
                add_css_class ("bounce");

                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                app_info.launch (null, context);
            } catch (Error e) {
                critical (e.message);
            }
            Timeout.add (400, () => {
                remove_css_class ("bounce");

                return Source.REMOVE;
            });

        });
    }

    public void update_windows (owned GLib.List<AppWindow>? new_windows) {
        if (new_windows == null) {
            windows = new GLib.List<AppWindow> ();
            return;
        }

        windows = (owned) new_windows;
    }

    public AppWindow? find_window (uint64 window_uid) {
        unowned var found_win = windows.search<uint64> (window_uid, (win, searched_uid) => {
            if (win.uid == searched_uid) {
                return 0;
            } else if (win.uid > searched_uid) {
                return 1;
            } else {
                return -1;
            }
        });

        if (found_win != null) {
            return found_win.data;
        } else {
            return null;
        }
    }

    private bool on_drop (Value val, double x, double y) {
        Launcher source;
        Launcher? target = this;

        var obj = val.get_object ();
        if (obj == null || !(obj is Launcher)) {
            return false;
        } else {
            source = (Launcher)obj;
        }

        if (source == this) {
            return false;
        }

        if (x < get_allocated_width () / 2) {
            target = (Launcher)get_prev_sibling ();
        }

        ((MainWindow)get_root ()).move_launcher_after (source, target);

        return true;
    }
}
