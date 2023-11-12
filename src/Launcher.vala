/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.FlowBoxChild {
    // Matches icon size and padding in Launcher.css
    public const int ICON_SIZE = 48;
    public const int PADDING = 6;

    public GLib.DesktopAppInfo app_info { get; construct; }
    public bool pinned { get; set; }

    public GLib.List<AppWindow> windows { get; private owned set; }

    private static Gtk.CssProvider css_provider;

    private Gtk.Image image;
    private int drag_offset_x = 0;
    private int drag_offset_y = 0;
    private string animate_css_class_name = "";
    private uint animate_timeout_id = 0;

    private Gtk.PopoverMenu popover;

    public Launcher (GLib.DesktopAppInfo app_info, bool pinned) {
        Object (app_info: app_info, pinned: pinned);
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

        var action_section = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            action_section.append (
                app_info.get_action_name (action),
                LauncherManager.ACTION_PREFIX + LauncherManager.LAUNCHER_ACTION_TEMPLATE.printf (app_info.get_id (), action)
            );
        }

        var pinned_section = new Menu ();
        pinned_section.append (
            _("Keep in Dock"),
            LauncherManager.ACTION_PREFIX + LauncherManager.LAUNCHER_PINNED_ACTION_TEMPLATE.printf (app_info.get_id ())
        );

        var model = new Menu ();
        if (action_section.get_n_items () > 0) {
            model.append_section (null, action_section);
        }
        model.append_section (null, pinned_section);

        popover = new Gtk.PopoverMenu.from_model (model) {
            autohide = true,
            position = TOP
        };
        popover.set_parent (this);

        image = new Gtk.Image () {
            gicon = app_info.get_icon ()
        };
        image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        child = image;
        tooltip_text = app_info.get_display_name ();

        var drag_source = new Gtk.DragSource () {
            actions = MOVE
        };
        add_controller (drag_source);
        drag_source.prepare.connect (on_drag_prepare);
        drag_source.drag_begin.connect (on_drag_begin);
        drag_source.drag_cancel.connect (on_drag_cancel);
        drag_source.drag_end.connect (() => image.gicon = app_info.get_icon ());

        var drop_target = new Gtk.DropTarget (typeof (Launcher), MOVE) {
            preload = true
        };
        add_controller (drop_target);
        drop_target.enter.connect (on_drop_enter);

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect (popover.popup);
    }

    ~Launcher () {
        popover.unparent ();
        popover.dispose ();
    }

    public void launch (string? action = null) {
        try {
            add_css_class ("bounce");

            var context = Gdk.Display.get_default ().get_app_launch_context ();
            context.set_timestamp (Gdk.CURRENT_TIME);

            if (action != null) {
                app_info.launch_action (action, context);
            } else {
                app_info.launch (null, context);
            }
        } catch (Error e) {
            critical (e.message);
        }

        Timeout.add (400, () => {
            remove_css_class ("bounce");

            return Source.REMOVE;
        });
    }

    public void animate_move (Gtk.DirectionType dir) {
        if (animate_timeout_id != 0) {
            Source.remove (animate_timeout_id);
            animate_timeout_id = 0;
            remove_css_class (animate_css_class_name);
        }

        if (dir == LEFT) {
            animate_css_class_name = "move-left";
        } else if (dir == RIGHT) {
            animate_css_class_name = "move-right";
        } else {
            warning ("Invalid direction type.");
            return;
        }

        add_css_class (animate_css_class_name);
        animate_timeout_id = Timeout.add (300, () => {
            remove_css_class (animate_css_class_name);
            animate_timeout_id = 0;
            return Source.REMOVE;
        });
    }

    public void update_windows (owned GLib.List<AppWindow>? new_windows) {
        if (new_windows == null) {
            windows = new GLib.List<AppWindow> ();
        } else {
            windows = (owned) new_windows;
        }
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

    private Gdk.ContentProvider? on_drag_prepare (double x, double y) {
        drag_offset_x = (int) x;
        drag_offset_y = (int) y;

        var val = Value (typeof (Launcher));
        val.set_object (this);
        return new Gdk.ContentProvider.for_value (val);
    }

    private void on_drag_begin (Gtk.DragSource drag_source, Gdk.Drag drag) {
        var paintable = new Gtk.WidgetPaintable (image); //Maybe TODO How TF can I get a paintable from a gicon?!?!?
        drag_source.set_icon (paintable.get_current_image (), drag_offset_x, drag_offset_y);
        image.clear ();
    }

    private bool on_drag_cancel (Gdk.Drag drag, Gdk.DragCancelReason reason) {
        if (pinned && reason == NO_TARGET) {
            var popover = new PoofPopover ();

            unowned var window = (MainWindow) get_root ();
            popover.set_parent (window);
            unowned var surface = window.get_surface ();

            double x, y;
            surface.get_device_position (drag.device, out x, out y, null);

            var rect = Gdk.Rectangle () {
                x = (int) x,
                y = (int) y
            };

            popover.set_pointing_to (rect);
            // 50 and -13 position the popover in a way that the cursor is in the top left corner.
            // (TODO: I got this with trial and error and I very much doubt that will be the same everywhere
            // and at different scalings so it needs testing.)
            // Although the drag_offset is also measured from the top left corner it works
            // the other way round (i.e it moves the cursor not the surface)
            // than set_offset so we put a - in front.
            popover.set_offset (
                50 - (drag_offset_x * (popover.width_request / ICON_SIZE)),
                -13 - (drag_offset_y * (popover.height_request / ICON_SIZE))
            );
            popover.popup ();
            popover.start_animation ();

            // var box = (Gtk.Box) parent;
            if (!windows.is_empty ()) {
                // LauncherManager.get_default ().move_launcher_after (this, (Launcher) box.get_last_child ());
            }

            pinned = false;

            return true;
        } else {
            image.gicon = app_info.get_icon ();
            return false;
        }
    }

    private Gdk.DragAction on_drop_enter (Gtk.DropTarget drop_target, double x, double y) {
        var val = drop_target.get_value ();
        if (val != null) {
            var obj = val.get_object ();

            if (obj != null && obj is Launcher) {
                Launcher source = (Launcher) obj;
                int target = get_index ();

                if (source.get_index () != target) {
                    if (((x > get_allocated_width () / 2) && get_next_sibling () == source) ||
                        ((x < get_allocated_width () / 2) && get_prev_sibling () != source)
                    ) {
                        target = target > 0 ? target-- : target;
                    }

                    LauncherManager.get_default ().move_launcher_after (source, target);
                }
            }
        }

        return MOVE;
    }
}
