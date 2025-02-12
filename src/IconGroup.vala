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
    }

    private void update_icons () {
        unowned Gtk.Widget? child;
        while ((child = get_first_child ())!= null) {
            remove (child);
        }

        unowned var app_system = AppSystem.get_default ();

        var n_attached_children = 0;
        for (var i = 0; i < workspace.di_workspace.windows.length; i++) {
            var di_window = workspace.di_workspace.windows[i];
            var app = app_system.get_app_for_window (di_window);
            if (app == null) {
                continue;
            }

            var image = new Gtk.Image () {
                pixel_size = 24
            };

            var icon = app.app_info.get_icon ();
            if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
                image.gicon = icon;
            } else {
                image.gicon = new ThemedIcon ("application-default-icon");
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