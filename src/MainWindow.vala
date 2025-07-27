/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Gtk.ApplicationWindow {
    private class Container : Gtk.Box {
        class construct {
            set_css_name ("dock");
        }
    }

    private class BottomMargin : Gtk.Widget {
        class construct {
            set_css_name ("bottom-margin");
        }
    }

    // Matches top margin in Launcher.css
    private const int TOP_MARGIN = 64;

    private Settings transparency_settings;
    private static Settings settings = new Settings ("io.elementary.dock");

    private Pantheon.Desktop.Shell? desktop_shell;
    private Pantheon.Desktop.Panel? panel;

    private Gtk.Box main_box;

    class construct {
        set_css_name ("dock-window");
    }

    construct {
        var launcher_manager = ItemManager.get_default ();

        overflow = VISIBLE;
        resizable = false;
        titlebar = new Gtk.Label ("") { visible = false };

        // Don't clip launchers to dock background https://github.com/elementary/dock/issues/275
        var overlay = new Gtk.Overlay () {
            child = new Container ()
        };
        overlay.add_overlay (launcher_manager);

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
        size_group.add_widget (overlay.child);
        size_group.add_widget (launcher_manager);

        main_box = new Gtk.Box (VERTICAL, 0);
        main_box.append (overlay);
        main_box.append (new BottomMargin ());
        child = main_box;

        remove_css_class ("background");

        // Fixes DnD reordering of launchers failing on a very small line between two launchers
        var drop_target_launcher = new Gtk.DropTarget (typeof (Launcher), MOVE);
        launcher_manager.add_controller (drop_target_launcher);

        launcher_manager.realize.connect (init_panel);

        settings.changed["autohide-mode"].connect (() => {
            if (panel != null) {
                panel.set_hide_mode (settings.get_enum ("autohide-mode"));
            } else {
                update_panel_x11 ();
            }
        });

        var transparency_schema = SettingsSchemaSource.get_default ().lookup ("io.elementary.desktop.wingpanel", true);
        if (transparency_schema != null && transparency_schema.has_key ("use-transparency")) {
            transparency_settings = new Settings ("io.elementary.desktop.wingpanel");
            transparency_settings.changed["use-transparency"].connect (update_transparency);
            update_transparency ();
        }
    }

    private void update_transparency () {
        if (transparency_settings.get_boolean ("use-transparency")) {
            remove_css_class ("reduce-transparency");
        } else {
            add_css_class ("reduce-transparency");

        }
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
        ((Gdk.Toplevel) get_surface ()).compute_size.connect ((size) => {
            // manually set shadow width since the additional margin we add to avoid icons clipping when
            // bouncing isn't added by default and instead counts to the frame
            unowned var surface = get_surface ();
            var item_manager_width = ItemManager.get_default ().get_width ();
            var shadow_size = (surface.width - item_manager_width) / 2;
            var top_margin = TOP_MARGIN + shadow_size;
            size.set_shadow_width (shadow_size, shadow_size, top_margin, shadow_size);
        });

        get_surface ().layout.connect_after (() => {
            // manually set input region since container's shadow are is the content of the window
            // and it still gets window events
            unowned var surface = get_surface ();
            var item_manager_width = ItemManager.get_default ().get_width ();
            var shadow_size = (surface.width - item_manager_width) / 2;
            var top_margin = TOP_MARGIN + shadow_size;
            surface.set_input_region (new Cairo.Region.rectangle ({
                shadow_size,
                top_margin,
                item_manager_width,
                surface.height - top_margin
            }));
        });

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
        } else {
            update_panel_x11 ();
        }
    }

    private void update_panel_x11 () {
        var display = Gdk.Display.get_default ();
        if (display is Gdk.X11.Display) {
            unowned var xdisplay = ((Gdk.X11.Display) display).get_xdisplay ();

            var window = ((Gdk.X11.Surface) get_surface ()).get_xid ();

            var prop = xdisplay.intern_atom ("_MUTTER_HINTS", false);

            var value = "anchor=8:hide-mode=%d:restore-previous-region=1".printf (settings.get_enum ("autohide-mode"));

            xdisplay.change_property (window, prop, X.XA_STRING, 8, 0, (uchar[]) value, value.length);
        }
    }
}
