/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Application : Gtk.Application {
    public Application () {
        Object (application_id: "io.elementary.dock");
    }

    protected override void activate () {
        if (active_window == null) {
            var main_window = new MainWindow ();

            add_window (main_window);
        }

        active_window.present_with_time (Gdk.CURRENT_TIME);
    }

    public static int main (string[] args) {
        return new Dock.Application ().run (args);
    }
}
