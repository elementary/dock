
public class FakeWindow : Granite.Bin {
    class construct {
        set_css_name ("dock");
    }
}

public class Dock.ApplicationDrawer : Gtk.Popover {
    private Gtk.Revealer revealer;

    construct {
        var label = new Gtk.Label ("test");

        var background = new Dock.MainWindow.Container () {
            height_request = 400,
            width_request = 400,
            overflow = VISIBLE
        };
        background.append (label);

        revealer = new Gtk.Revealer () {
            child = background,
            reveal_child = false,
            transition_duration = 400,
            valign = END,
            transition_type = SLIDE_UP
        };

        var overlay = new Gtk.Overlay ();
        overlay.add_overlay (revealer);

        child = overlay;
        position = TOP;
        halign = CENTER;
        has_arrow = false;
        height_request = 500;
        width_request = 500;
        margin_bottom = 12;
        autohide = false;

        remove_css_class ("background");

        revealer.notify["child-revealed"].connect (() => {
            if (!revealer.child_revealed) {
                popdown ();
                unparent ();
            }
        });
    }

    public void reveal () {
        popup ();
        revealer.reveal_child = true;
    }

    public void unreveal () {
        revealer.reveal_child = false;
    }
}
