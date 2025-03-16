/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.BaseItem : Gtk.Box {
    public enum State {
        ACTIVE,
        INACTIVE,
        HIDDEN
    }

    protected static GLib.Settings dock_settings;

    static construct {
        dock_settings = new GLib.Settings ("io.elementary.dock");
    }

    public signal void removed ();
    public signal void revealed_done ();

    public int icon_size { get; set; }
    public double current_pos { get; set; }

    private bool _moving;
    public bool moving {
        get { return _moving; }
        set {
            _moving = value;
            visible = !value;
            running_revealer.reveal_child = !value && state != HIDDEN;
        }
    }

    private State _state;
    public State state {
        get { return _state; }
        set {
            _state = value;
            running_revealer.reveal_child = (value != HIDDEN) && !moving;
            running_revealer.sensitive = value == ACTIVE;
        }
    }

    protected Gtk.Overlay overlay;
    protected Gtk.GestureClick gesture_click;

    private Gtk.Revealer running_revealer;

    private Adw.TimedAnimation fade;
    private Adw.TimedAnimation reveal;
    private Adw.TimedAnimation timed_animation;

    private int drag_offset_x = 0;
    private int drag_offset_y = 0;

    private BaseItem () {}

    construct {
        orientation = VERTICAL;

        overlay = new Gtk.Overlay ();

        var running_indicator = new Gtk.Image.from_icon_name ("pager-checked-symbolic");
        running_indicator.add_css_class ("running-indicator");

        running_revealer = new Gtk.Revealer () {
            can_target = false,
            child = running_indicator,
            overflow = VISIBLE,
            transition_type = CROSSFADE,
            valign = END
        };

        append (overlay);
        append (running_revealer);

        icon_size = dock_settings.get_int ("icon-size");
        dock_settings.changed["icon-size"].connect (() => {
            icon_size = dock_settings.get_int ("icon-size");
        });

        fade = new Adw.TimedAnimation (
            this, 0, 1,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                opacity = val;
            })
        ) {
            easing = EASE_IN_OUT_QUAD
        };

        reveal = new Adw.TimedAnimation (
            overlay, icon_size, 0,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                overlay.allocate (icon_size, icon_size, -1,
                    new Gsk.Transform ().translate (Graphene.Point () { y = (float) val }
                ));
            })
        );

        reveal.done.connect (set_revealed_finish);

        unowned var item_manager = ItemManager.get_default ();
        var animation_target = new Adw.CallbackAnimationTarget ((val) => {
            item_manager.move (this, val, 0);
            current_pos = val;
        });

        timed_animation = new Adw.TimedAnimation (
            this,
            0,
            0,
            200,
            animation_target
        ) {
            easing = EASE_IN_OUT_QUAD
        };

        gesture_click = new Gtk.GestureClick ();
        add_controller (gesture_click);

        var drag_source = new Gtk.DragSource () {
            actions = MOVE
        };
        add_controller (drag_source);
        drag_source.prepare.connect (on_drag_prepare);
        drag_source.drag_begin.connect (on_drag_begin);
        drag_source.drag_cancel.connect (on_drag_cancel);
        drag_source.drag_end.connect (on_drag_end);

        var drop_target = new Gtk.DropTarget (get_type (), MOVE) {
            preload = true
        };
        add_controller (drop_target);
        drop_target.enter.connect (on_drop_enter);
        drop_target.drop.connect (on_drop);
    }

    public void set_revealed (bool revealed) {
        fade.skip ();
        reveal.skip ();

        // Avoid a stutter at the beginning
        opacity = 0;
        // clip launcher to dock size until we finish animating
        overflow = HIDDEN;

        if (revealed) {
            reveal.easing = EASE_OUT_BACK;
        } else {
            fade.duration = Granite.TRANSITION_DURATION_CLOSE;
            fade.reverse = true;

            reveal.duration = Granite.TRANSITION_DURATION_CLOSE;
            reveal.easing = EASE_IN_OUT_QUAD;
            reveal.reverse = true;
        }

        fade.play ();
        reveal.play ();
    }

    private void set_revealed_finish () {
        overflow = VISIBLE;
        revealed_done ();
    }

    /**
     * Makes the launcher animate a move to the given position. Make sure to
     * always use this instead of manually calling Gtk.Fixed.move on the manager
     * when moving a launcher so that its current_pos is always up to date.
     */
    public void animate_move (double new_position) {
        timed_animation.value_from = current_pos;
        timed_animation.value_to = new_position;

        timed_animation.play ();
    }

    /**
     * If the icon group isn't needed anymore call this otherwise it won't be freed.
     */
    public virtual void cleanup () {
        fade = null;
        reveal = null;
        timed_animation = null;
    }

    private Gdk.ContentProvider? on_drag_prepare (double x, double y) {
        drag_offset_x = (int) x;
        drag_offset_y = (int) y;

        var val = Value (get_type ());
        val.set_object (this);
        return new Gdk.ContentProvider.for_value (val);
    }

    private void on_drag_begin (Gtk.DragSource drag_source, Gdk.Drag drag) {
        var paintable = new Gtk.WidgetPaintable (overlay);
        drag_source.set_icon (paintable.get_current_image (), drag_offset_x, drag_offset_y);

        moving = true;
    }

    private bool on_drag_cancel (Gdk.Drag drag, Gdk.DragCancelReason reason) {
        moving = false;
        return drag_cancelled (drag, reason);
    }

    protected virtual bool drag_cancelled (Gdk.Drag drag, Gdk.DragCancelReason reason) {
        return true;
    }

    private void on_drag_end () {
        if (moving) {
            moving = false;
        }
    }

    private Gdk.DragAction on_drop_enter (Gtk.DropTarget drop_target, double x, double y) {
        var val = drop_target.get_value ();
        if (val != null) {
            var obj = val.get_object ();

            if (obj != null && obj.get_type () == get_type ()) {
                calculate_dnd_move ((BaseItem) obj, x, y);
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
    public void calculate_dnd_move (BaseItem source, double x, double y) {
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

    private bool on_drop (Value val) {
        if (val.type () == get_type ()) {
            ((BaseItem) val.get_object ()).moving = false;
            return true;
        }
        return false;
    }
}
