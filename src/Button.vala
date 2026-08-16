/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

public class Dock.Button : Granite.Bin {
    public signal void clicked (uint button, uint32 timestamp);

    public uint mouse_button { get; set; default = 1; }

    class construct {
        set_accessible_role (BUTTON);
        set_css_name ("dock-button");
    }

    construct {
        focusable = true;

        var gesture_click = new Gtk.GestureClick ();
        bind_property ("mouse-button", gesture_click, "button", SYNC_CREATE);
        gesture_click.released.connect (on_released);
        add_controller (gesture_click);

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        add_controller (key_controller);
    }

    private void on_released (Gtk.GestureClick gesture_click, int n_press, double x, double y) {
        clicked (gesture_click.get_current_button (), gesture_click.get_current_event_time ());
    }

    private bool on_key_pressed (
        Gtk.EventControllerKey key_controller,
        uint keyval,
        uint keycode,
        Gdk.ModifierType state
    ) {
        if (keyval == Gdk.Key.space || keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
            clicked (Gdk.BUTTON_PRIMARY, key_controller.get_current_event_time ());
            return true;
        }

        return false;
    }
}
