/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.ApplicationMenu : Gtk.ApplicationWindow {
    private Detective.Engine engine;

    construct {
        engine = new Detective.Engine ();

        resizable = false;
        child = new MainView (engine);
        titlebar = new Gtk.Grid () { visible = false };
        hide_on_close = true;

        notify["is-active"].connect (on_is_active_changed);

        child.map.connect (init_panel);

        add_css_class ("application-menu");
    }

    private void on_is_active_changed () {
        if (!is_active) {
            //  close ();
        }
    }

    private static Wl.RegistryListener registry_listener;
    private void init_panel () {
        warning ("Initializing panel");
        registry_listener.global = registry_handle_global;

        unowned var display = (Gdk.Wayland.Display) Gdk.Display.get_default ();

        unowned var wl_display = display.get_wl_display ();
        var wl_registry = wl_display.get_registry ();
        wl_registry.add_listener (registry_listener, this);

        wl_display.roundtrip ();
    }

    private void registry_handle_global (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
        if (@interface == "io_elementary_pantheon_shell_v1") {
            var desktop_shell = wl_registry.bind<Pantheon.Desktop.Shell> (name, ref Pantheon.Desktop.Shell.iface, uint32.min (version, 1));

            unowned var surface = (Gdk.Wayland.Surface) get_surface ();
            unowned var wl_surface = surface.get_wl_surface ();

            var panel = desktop_shell.get_panel (wl_surface);
            panel.add_blur (0, 0, 0, 0, 8);
            warning ("Add blur");
        }
    }
}
