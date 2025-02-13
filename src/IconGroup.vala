// TODO: Copyright

public class Dock.IconGroup : Gtk.Grid {
    private const int MAX_IN_ROW = 2;
    private const int MAX_IN_COLUMN = 2;
    private const int MAX_N_CHILDREN = MAX_IN_ROW * MAX_IN_COLUMN;

    public Workspace workspace { get; construct; }

    public signal void removed ();
    public signal void fade_done ();

    // Matches icon size and padding in Launcher.css
    public const int ICON_SIZE = 48;
    public const int PADDING = 6;

    private Adw.TimedAnimation fade;
    private Adw.TimedAnimation timed_animation;

    public double current_pos { get; set; }

    class construct {
        set_css_name ("icongroup");
    }

    public IconGroup (Workspace workspace) {
        Object (workspace: workspace);
    }

    construct {
        workspace.windows_changed.connect (update_icons);
        update_icons ();

        workspace.removed.connect (() => removed ());

        fade = new Adw.TimedAnimation (
            this, 0, 1,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                opacity = val;
            })
        ) {
            easing = EASE_IN_OUT_QUAD
        };

        unowned var launcher_manager = LauncherManager.get_default ();
        var animation_target = new Adw.CallbackAnimationTarget ((val) => {
            launcher_manager.move (this, val, 0);
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

        var gesture_click = new Gtk.GestureClick () {
            button = 0
        };
        add_controller (gesture_click);
        gesture_click.released.connect (workspace.activate);
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

    private void update_icons () {
        unowned Gtk.Widget? child;
        while ((child = get_first_child ()) != null) {
            remove (child);
        }

        for (var i = 0; i < int.min (workspace.windows.size, 4); i++) {
            var image = new Gtk.Image.from_gicon (workspace.windows[i].icon) {
                pixel_size = 24
            };

            attach (image, i % MAX_IN_ROW, i / MAX_IN_COLUMN, 1, 1);
        }
    }

    public void set_revealed (bool revealed) {
        fade.skip ();

        // Avoid a stutter at the beginning
        opacity = 0;
        // clip launcher to dock size until we finish animating
        overflow = HIDDEN;

        if (!revealed) {
            fade.duration = Granite.TRANSITION_DURATION_CLOSE;
            fade.reverse = true;
        }

        fade.play ();

        fade.done.connect (() => {
            overflow = VISIBLE;
            fade_done ();
        });
    }

    /**
     * If the icon group isn't needed anymore call this otherwise it won't be freed.
     */
    public void cleanup () {
        timed_animation = null;
    }
}
