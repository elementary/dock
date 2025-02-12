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
        workspace.notify["di-workspace"].connect (update_icons);
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
        warning ("Updating icons");

        unowned Gtk.Widget? child;
        while ((child = get_first_child ())!= null) {
            remove (child);
        }

        var n_attached_children = 0;
        for (var i = 0; i < workspace.di_workspace.windows.length; i++) {
            var image = new Gtk.Image () {
                pixel_size = 24
            };

            unowned var app_id = workspace.di_workspace.windows[i].properties["app-id"].get_string ();
            if (app_id == null) {
                image.gicon = new ThemedIcon ("application-default-icon");
            } else {
                var app_info = new GLib.DesktopAppInfo (app_id);
                if (app_info == null) {
                    image.gicon = new ThemedIcon ("application-default-icon");
                } else {
                    var icon = app_info.get_icon ();
                    if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
                        image.gicon = icon;
                    } else {
                        image.gicon = new ThemedIcon ("application-default-icon");
                    }
                }
            }

            attach (image, n_attached_children % MAX_IN_ROW, n_attached_children / MAX_IN_COLUMN, 1, 1);
            n_attached_children += 1;

            if (n_attached_children == MAX_N_CHILDREN) {
                break;
            }
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

    public void cleanup () { }
}