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

        app.notify["running-on-active-workspace"].connect (update_active_state);
        app.notify["running"].connect (update_active_state);
        update_active_state ();

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

    protected override bool drag_cancelled (Gdk.Drag drag, Gdk.DragCancelReason reason) {
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
            return base.drag_cancelled (drag, reason);
        }
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
        badge_revealer.reveal_child = app.count_visible
            && (notify_settings == null || !notify_settings.get_boolean ("do-not-disturb"));
    }

    private void update_progress_revealer () {
        progress_revealer.reveal_child = app.progress_visible;

        // See comment above and https://github.com/elementary/dock/issues/279
        if (progress_revealer.reveal_child && progress_revealer.child == null) {
            var progress_bar = new Gtk.ProgressBar () {
                valign = END
            };
            app.bind_property ("progress", progress_bar, "fraction", SYNC_CREATE);

            progress_revealer.child = progress_bar;
        }
    }

    private void update_active_state () {
        if (!app.running) {
            state = HIDDEN;
        } else {
            state = app.running_on_active_workspace ? State.ACTIVE : State.INACTIVE;
        }
    }
}
