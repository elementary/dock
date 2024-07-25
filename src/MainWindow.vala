/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    private static Settings settings = new Settings ("io.elementary.dock");

    private Pantheon.Desktop.Shell? desktop_shell;
    private Pantheon.Desktop.Panel? panel;

    PantheonShellX11? pantheon_shell_x11_dbus;

    class construct {
        set_css_name ("dock");
    }

    construct {
        var launcher_manager = LauncherManager.get_default ();

        child = launcher_manager;
        overflow = VISIBLE;
        resizable = false;
        titlebar = new Gtk.Label ("") { visible = false };

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        launcher_manager.add_controller (drop_target_launcher);

        show.connect (() => {
            if (is_wayland ()) {
                init_panel ();
            } else {
                init_x11_panel ();
            }
        });

        settings.changed.connect ((key) => {
            if (key != "autohide-mode") {
                return;
            }

            if (is_wayland () && panel != null) {
                panel.set_hide_mode (settings.get_enum ("autohide-mode"));
            } else if (!is_wayland () && pantheon_shell_x11_dbus != null && title != null) {
                try {
                    pantheon_shell_x11_dbus.set_hide_mode (title, settings.get_enum ("autohide-mode"));
                } catch (GLib.Error e) {
                    warning ("Unable to update the hide mode: %s", e.message);
                }
            }
        });
    }

    public void registry_handle_global (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
        if (@interface == "io_elementary_pantheon_shell_v1") {
            desktop_shell = wl_registry.bind<Pantheon.Desktop.Shell> (name, ref Pantheon.Desktop.Shell.iface, uint32.min (version, 1));
            unowned var surface = get_surface ();
            if (surface is Gdk.Wayland.Surface) {
                unowned var wl_surface = ((Gdk.Wayland.Surface) surface).get_wl_surface ();
                panel = desktop_shell.get_panel (wl_surface);
                panel.set_anchor (BOTTOM);
                panel.set_hide_mode (settings.get_enum ("autohide-mode"));
            }
        }
    }

    private static Wl.RegistryListener registry_listener;
    private void init_panel () {
        registry_listener.global = registry_handle_global;
        unowned var display = Gdk.Display.get_default ();
        if (display is Gdk.Wayland.Display) {
            unowned var wl_display = ((Gdk.Wayland.Display) display).get_wl_display ();
            var wl_registry = wl_display.get_registry ();
            wl_registry.add_listener (
                registry_listener,
                this
            );

            if (wl_display.roundtrip () < 0) {
                return;
            }
        }
    }

    private bool is_wayland () {
        return Gdk.Display.get_default () is Gdk.Wayland.Display;
    }

    private void init_x11_panel () requires (title != null) {
        try {
            pantheon_shell_x11_dbus = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.gala.PantheonShellX11", "/io/elementary/gala/PantheonShellX11");
            pantheon_shell_x11_dbus.set_anchor (title, BOTTOM);
            pantheon_shell_x11_dbus.set_hide_mode (title, settings.get_enum ("autohide-mode"));
        } catch (GLib.Error e) {
            critical ("Unable to setup PantheonShellX11: %s", e.message);
        }
    }
}
