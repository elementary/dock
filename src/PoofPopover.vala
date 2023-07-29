/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

public class Dock.PoofPopover : Gtk.Popover {
    private Gtk.Adjustment vadjustment;
    private int poof_frames;

    construct {
        var texture = Gdk.Texture.from_resource ("/io/elementary/dock/poof.svg");

        var poof_size = texture.width;
        poof_frames = (int) Math.floor (texture.height / poof_size);

        var picture = new Gtk.Picture.for_paintable (texture) {
            width_request = Launcher.ICON_SIZE,
            height_request = Launcher.ICON_SIZE * poof_frames,
            keep_aspect_ratio = true
        };

        var scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            child = picture,
            vscrollbar_policy = EXTERNAL
        };

        vadjustment = scrolled_window.get_vadjustment ();

        height_request = Launcher.ICON_SIZE;
        width_request = Launcher.ICON_SIZE;
        has_arrow = false;
        remove_css_class ("background");
        child = scrolled_window;
    }

    public void start_animation () {
        var frame = 1;
        Timeout.add (30, () => {
            var adjustment_step = (int) vadjustment.get_upper () / poof_frames;
            vadjustment.value = vadjustment.value + adjustment_step;
            if (frame <= poof_frames) {
                frame++;
                return Source.CONTINUE;
            } else {
                popdown ();
                Idle.add (() => {
                    unparent ();
                    return Source.REMOVE;
                });
                return Source.REMOVE;
            }
        });
    }
}
