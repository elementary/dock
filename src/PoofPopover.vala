public class Dock.PoofPopover : Gtk.Popover {
    construct {
        var animation = Gtk.MediaFile.for_resource ("/io/elementary/dock/poof.mp4");
        animation.loop = true;

        var picture = new Gtk.Picture.for_paintable (animation) {
            height_request = 48,
            width_request = 48
        };

        height_request = Launcher.ICON_SIZE;
        width_request = Launcher.ICON_SIZE;
        halign = CENTER;
        valign = CENTER;
        has_arrow = false;
        remove_css_class ("background");
        child = new Gtk.Label ("test");

        animation.play_now ();

        Timeout.add (2000, () => {
            popdown ();
            return Source.REMOVE;
        });
    }
}
