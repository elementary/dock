/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023-2025 elementary, Inc. (https://elementary.io)
 */

// Not sure if Gtk.Button is the best method for this
public class Dock.AppMenuButton : Gtk.Button {
    private AppMenuWindow window;

    construct {
        window = new AppMenuWindow ();

        set_label ("AppMenu");
        // TODO: design icon and add it here somehow?
        //set_icon_name ("AppMenu");
        set_has_frame (false);

        clicked.connect (toggleWindow);
        window.present ();
    }

    private void toggleWindow() {
        if (window.is_visible ()) {
            window.hide ();
            return;
        }

        window.present ();
    }
}

