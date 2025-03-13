/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.ApplicationMenuButton : BaseItem {
    class construct {
        set_css_name ("launcher");
    }

    construct {
        var add_image = new Gtk.Image.from_icon_name ("applications-other") {
            hexpand = true,
            vexpand = true
        };

        overlay.child = add_image;

        dock_settings.bind ("icon-size", this, "width-request", DEFAULT);
        dock_settings.bind ("icon-size", this, "height-request", DEFAULT);

        dock_settings.bind_with_mapping (
            "icon-size", add_image, "pixel_size", DEFAULT | GET,
            (value, variant, user_data) => {
                var icon_size = variant.get_int32 ();
                value.set_int (icon_size / 2);
                return true;
            },
            (value, expected_type, user_data) => {
                return new Variant.maybe (null, null);
            },
            null, null
        );

        gesture_click.button = Gdk.BUTTON_PRIMARY;
        gesture_click.released.connect (on_clicked);
    }

    private void on_clicked () {
        activate_action (Application.ACTION_PREFIX + Application.TOGGLE_APPLICATION_MENU_ACTION, null);
    }
}
