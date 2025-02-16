/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

 public class Dock.BaseItem : Gtk.Box {
    protected static GLib.Settings dock_settings;

    static construct {
        dock_settings = new GLib.Settings ("io.elementary.dock");
    }

    public signal void removed ();
    public signal void revealed_done ();

    public int icon_size { get; set; }
    public double current_pos { get; set; }

    protected Gtk.Overlay overlay;
    protected Gtk.Revealer running_revealer;
    protected Gtk.GestureClick gesture_click;

    private Adw.TimedAnimation fade;
    private Adw.TimedAnimation reveal;
    private Adw.TimedAnimation timed_animation;

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

        reveal.done.connect (() => {
            overflow = VISIBLE;
            revealed_done ();
        });
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
}
