/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : BaseItem {
    private const int DND_TIMEOUT = 1000;

    private static Settings? notify_settings;

    static construct {
        if (SettingsSchemaSource.get_default ().lookup ("io.elementary.notifications", true) != null) {
            notify_settings = new Settings ("io.elementary.notifications");
        }
    }

    // Matches icon size and padding in Launcher.css
    public const int ICON_SIZE = 48;
    public const int PADDING = 6;

    public const string ACTION_GROUP_PREFIX = "app-actions";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string PINNED_ACTION = "pinned";
    public const string APP_ACTION = "action.%s";

    public App app { get; construct; }

    private bool _moving = false;
    public bool moving {
        get {
            return _moving;
        }

        set {
            _moving = value;

            if (value) {
                image.clear ();
            } else {
                image.gicon = app.app_info.get_icon ();
            }

            update_badge_revealer ();
            update_progress_revealer ();
            update_running_revealer ();
        }
    }

    private Gtk.Image image;
    private Gtk.Revealer progress_revealer;
    private Gtk.Revealer badge_revealer;
    private Adw.TimedAnimation bounce_up;
    private Adw.TimedAnimation bounce_down;
    private Gtk.PopoverMenu popover;

    private Binding current_count_binding;

    private int drag_offset_x = 0;
    private int drag_offset_y = 0;

    private uint queue_dnd_cycle_id = 0;

    private bool flagged_for_removal = false;

    public Launcher (App app) {
        Object (app: app);
    }

    class construct {
        set_css_name ("launcher");
    }

    construct {
        popover = new Gtk.PopoverMenu.from_model (app.menu_model) {
            autohide = true,
            position = TOP
        };
        popover.set_parent (this);

        image = new Gtk.Image ();

        var icon = app.app_info.get_icon ();
        if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
            image.gicon = icon;
        } else {
            image.gicon = new ThemedIcon ("application-default-icon");
        }

        var badge = new Gtk.Label ("!") {
            halign = END,
            valign = START
        };
        badge.add_css_class (Granite.STYLE_CLASS_BADGE);

        badge_revealer = new Gtk.Revealer () {
            can_target = false,
            child = badge,
            transition_type = SWING_UP
        };

        progress_revealer = new Gtk.Revealer () {
            can_target = false,
            transition_type = CROSSFADE
        };

        overlay.child = image;
        overlay.add_overlay (badge_revealer);
        overlay.add_overlay (progress_revealer);

        tooltip_text = app.app_info.get_display_name ();

        insert_action_group (ACTION_GROUP_PREFIX, app.action_group);

        // We have to destroy the progressbar when it is not needed otherwise it will
        // cause continuous layouting of the surface see https://github.com/elementary/dock/issues/279
        progress_revealer.notify["child-revealed"].connect (() => {
            if (!progress_revealer.child_revealed) {
                progress_revealer.child = null;
            }
        });

        app.launched.connect (animate_launch);
        app.removed.connect (() => removed ());

        var bounce_animation_target = new Adw.CallbackAnimationTarget ((val) => {
            var height = overlay.get_height ();
            var width = overlay.get_width ();

            overlay.allocate (
                width, height, -1,
                new Gsk.Transform ().translate (Graphene.Point () { y = (int) val })
            );
        });

        bounce_down = new Adw.TimedAnimation (
            this,
            0,
            0,
            600,
            bounce_animation_target
        ) {
            easing = EASE_OUT_BOUNCE
        };
        bounce_down.done.connect (() => {
            if (app.launching) {
                Timeout.add_once (200, animate_launch);
            }
        });

        bounce_up = new Adw.TimedAnimation (
            this,
            0,
            0,
            200,
            bounce_animation_target
        ) {
            easing = EASE_IN_OUT_QUAD
        };
        bounce_up.done.connect (bounce_down.play);

        var drag_source = new Gtk.DragSource () {
            actions = MOVE
        };
        add_controller (drag_source);
        drag_source.prepare.connect (on_drag_prepare);
        drag_source.drag_begin.connect (on_drag_begin);
        drag_source.drag_cancel.connect (on_drag_cancel);
        drag_source.drag_end.connect (() => {
            if (!flagged_for_removal) {
                moving = false;
            }
        });

        var drop_target = new Gtk.DropTarget (typeof (Launcher), MOVE) {
            preload = true
        };
        add_controller (drop_target);
        drop_target.enter.connect (on_drop_enter);

        gesture_click.button = 0;
        gesture_click.released.connect (on_click_released);

        var scroll_controller = new Gtk.EventControllerScroll (VERTICAL);
        add_controller (scroll_controller);
        scroll_controller.scroll.connect ((dx, dy) => {
            app.next_window.begin (dy > 0);
            return Gdk.EVENT_STOP;
        });

        bind_property ("icon-size", image, "pixel-size", SYNC_CREATE);

        app.notify["count-visible"].connect (update_badge_revealer);
        update_badge_revealer ();
        current_count_binding = app.bind_property ("current_count", badge, "label", SYNC_CREATE,
            (binding, srcval, ref targetval) => {
                var src = (int64) srcval;

                if (src > 0) {
                    targetval.set_string ("%lld".printf (src));
                } else {
                    targetval.set_string ("!");
                }

                return true;
            }, null
        );

        if (notify_settings != null) {
            notify_settings.changed["do-not-disturb"].connect (update_badge_revealer);
        }

        app.notify["progress-visible"].connect (update_progress_revealer);
        update_progress_revealer ();

        app.bind_property ("running-on-active-workspace", running_revealer, "sensitive", SYNC_CREATE);

        app.notify["running"].connect (update_running_revealer);
        update_running_revealer ();

        var drop_target_file = new Gtk.DropTarget (typeof (File), COPY);
        add_controller (drop_target_file);

        drop_target_file.enter.connect ((x, y) => {
            var _launcher_manager = ItemManager.get_default ();
            if (_launcher_manager.added_launcher != null) {
                calculate_dnd_move (_launcher_manager.added_launcher, x, y);
            }
            return COPY;
        });

        drop_target_file.drop.connect (() => {
            var _launcher_manager = ItemManager.get_default ();
            if (_launcher_manager.added_launcher != null) {
                _launcher_manager.added_launcher.moving = false;
                _launcher_manager.added_launcher = null;
            }
        });

        var drop_controller_motion = new Gtk.DropControllerMotion ();
        add_controller (drop_controller_motion);
        drop_controller_motion.enter.connect (queue_dnd_cycle);
        drop_controller_motion.leave.connect (remove_dnd_cycle);
    }

    ~Launcher () {
        popover.unparent ();
        popover.dispose ();
    }

    /**
     * {@inheritDoc}
     */
    public override void cleanup () {
        base.cleanup ();
        bounce_down = null;
        bounce_up = null;
        current_count_binding.unbind ();
        remove_dnd_cycle ();
    }

    private void on_click_released (int n_press, double x, double y) {
        var event_display = gesture_click.get_current_event ().get_display ();
        var context = event_display.get_app_launch_context ();
        context.set_timestamp (gesture_click.get_current_event_time ());

        switch (gesture_click.get_current_button ()) {
            case Gdk.BUTTON_PRIMARY:
                app.launch (context);
                break;
            case Gdk.BUTTON_MIDDLE:
                if (app.launch_new_instance (context)) {
                    animate_launch ();
                } else {
                    event_display.beep ();
                }
                break;
            case Gdk.BUTTON_SECONDARY:
                popover.popup ();
                break;
        }
    }

    private void animate_launch () {
        if (bounce_up.state == PLAYING || bounce_down.state == PLAYING) {
            return;
        }

        bounce_up.value_to = -0.5 * overlay.get_height ();
        bounce_down.value_from = bounce_up.value_to;

        bounce_up.play ();
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
        moving = true;

        app.pinned = true; // Dragging communicates an implicit intention to pin the app
    }

    private bool on_drag_cancel (Gdk.Drag drag, Gdk.DragCancelReason reason) {
        if (app.pinned && reason == NO_TARGET) {
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

            app.pinned = false;
            flagged_for_removal = true;

            return true;
        } else {
            moving = false;
            return false;
        }
    }

    private Gdk.DragAction on_drop_enter (Gtk.DropTarget drop_target, double x, double y) {
        var val = drop_target.get_value ();
        if (val != null) {
            var obj = val.get_object ();

            if (obj != null && obj is Launcher) {
                calculate_dnd_move ((Launcher) obj, x, y);
            }
        }

        return MOVE;
    }

    /**
     * Calculates which side of #this source should be moved to.
     * Depends on the direction from which the mouse cursor entered
     * and whether source is already next to #this.
     *
     * @param source the launcher that's currently being reordered
     * @param x pointer x position
     * @param y pointer y position
     */
    private void calculate_dnd_move (Launcher source, double x, double y) {
        var launcher_manager = ItemManager.get_default ();

        int target_index = launcher_manager.get_index_for_launcher (this);
        int source_index = launcher_manager.get_index_for_launcher (source);

        if (source_index == target_index) {
            return;
        }

        if (((x > get_width () / 2) && target_index + 1 == source_index) || // Cursor entered from the RIGHT and source IS our neighbouring launcher to the RIGHT
            ((x < get_width () / 2) && target_index - 1 != source_index)    // Cursor entered from the LEFT and source is NOT our neighbouring launcher to the LEFT
        ) {
            // Move it to the left of us
            target_index = target_index > 0 ? target_index-- : target_index;
        }
        // Else move it to the right of us

        launcher_manager.move_launcher_after (source, target_index);
    }

    private void queue_dnd_cycle () {
        queue_dnd_cycle_id = Timeout.add (DND_TIMEOUT, () => {
            app.next_window.begin (false);
            return Source.CONTINUE;
        });
    }

    private void remove_dnd_cycle () {
        if (queue_dnd_cycle_id > 0) {
            Source.remove (queue_dnd_cycle_id);
            queue_dnd_cycle_id = 0;
        }
    }

    private void update_badge_revealer () {
        badge_revealer.reveal_child = !moving && app.count_visible
            && (notify_settings == null || !notify_settings.get_boolean ("do-not-disturb"));
    }

    private void update_progress_revealer () {
        progress_revealer.reveal_child = !moving && app.progress_visible;

        // See comment above and https://github.com/elementary/dock/issues/279
        if (progress_revealer.reveal_child && progress_revealer.child == null) {
            var progress_bar = new Gtk.ProgressBar () {
                valign = END
            };
            app.bind_property ("progress", progress_bar, "fraction", SYNC_CREATE);

            progress_revealer.child = progress_bar;
        }
    }

    private void update_running_revealer () {
        running_revealer.reveal_child = !moving && app.running;
    }
}
