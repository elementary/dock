/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.Button {
    // Matches icon size and padding in Launcher.css
    public const int ICON_SIZE = 48;
    public const int PADDING = 6;

    public GLib.DesktopAppInfo app_info { get; construct; }
    public bool pinned { get; set; }

    public GLib.List<AppWindow> windows { get; private owned set; }

    private static Gtk.CssProvider css_provider;
    private string css_class_name = "";
    private uint animate_timeout_id = 0;

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

        int drag_offset_x = 0;
        int drag_offset_y = 0;
        drag_source.prepare.connect ((x, y) => {
            drag_offset_x = (int) x;
            drag_offset_y = (int) y;

            var val = Value (typeof (Launcher));
            val.set_object (this);
            return new Gdk.ContentProvider.for_value (val);
        });

        drag_source.drag_begin.connect ((drag) => {
            var paintable = new Gtk.WidgetPaintable (image); //Maybe TODO How TF can I get a paintable from a gicon?!?!?
            drag_source.set_icon (paintable.get_current_image (), drag_offset_x, drag_offset_y);
            image.clear ();
        });

        drag_source.drag_cancel.connect ((drag, reason) => {
            if (pinned && reason == NO_TARGET) {
                var popover = new PoofPopover ();

                var window = (MainWindow)get_root ();
                popover.set_parent (window);
                var surface = window.get_surface ();

                double x, y;
                Gdk.ModifierType mask;
                surface.get_device_position (drag.device, out x, out y, out mask);

                var rect = Gdk.Rectangle ();
                rect.x = (int)x;
                rect.y = (int)y;

                popover.set_pointing_to (rect);
                // ICON_SIZE / 4 and -(ICON_SIZE / 4) position the popover in a way that the cursor is in the top left corner.
                // The drag_offset is also measured from the top left corner but works
                // the other way round (i.e it moves the cursor not the surface)
                // than set_offset so we put a - in front.
                popover.set_offset (ICON_SIZE / 4 - drag_offset_x, - (ICON_SIZE / 4) - drag_offset_y);
                popover.popup ();
                popover.start_animation ();

                window.remove_launcher (this);

                return true;
            } else {
                image.gicon = app_info.get_icon ();
                return false;
            }
        });

        drag_source.drag_end.connect (() => image.gicon = app_info.get_icon ());

        var drop_target = new Gtk.DropTarget (typeof (Launcher), MOVE) {
            preload = true
        };
        box.add_controller (drop_target);
        drop_target.enter.connect (on_drop_enter);

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

    public void animate_move (Gtk.DirectionType dir) {
        if (animate_timeout_id != 0) {
            Source.remove (animate_timeout_id);
            remove_css_class (css_class_name);
        }
        foreach (var css_class in get_css_classes ()) {
            print (css_class);
        }
        if (dir == LEFT) {
            css_class_name = "move-left";
        } else if (dir == RIGHT) {
            css_class_name = "move-right";
        }

        print (css_class_name);
        add_css_class (css_class_name);
        animate_timeout_id = Timeout.add (300, () => {
            remove_css_class (css_class_name);
            animate_timeout_id = 0;
            return Source.REMOVE;
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

    private Gdk.DragAction on_drop_enter (Gtk.DropTarget drop_target, double x, double y) {
        var val = drop_target.get_value ();
        if (val != null) {
            var obj = val.get_object ();

            if (obj != null && obj is Launcher) {
                Launcher source = (Launcher)obj;
                Launcher target = this;

                if (source != target) {
                    if ((x > get_allocated_width () / 2) && get_next_sibling () == source) {
                        target = (Launcher)get_prev_sibling ();
                    } else if ((x < get_allocated_width () / 2) && get_prev_sibling () != source) {
                        target = (Launcher)get_prev_sibling ();
                    }

                    ((MainWindow)get_root ()).move_launcher_after (source, target);
                }
            }
        }

        return MOVE;
    }
}
