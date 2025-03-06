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

    // Keep in sync with CSS
    private const int TOP_PADDING = 64;
    private const int BORDER_RADIUS = 9;

    private Settings transparency_settings;
    private static Settings settings = new Settings ("io.elementary.dock");

    private Pantheon.Desktop.Shell? desktop_shell;
    private Pantheon.Desktop.Panel? panel;
    private PantheonBlur.Blur? blur;

    private Gtk.Box main_box;
    private int full_height = 0;
    private int visible_width = 0;
    private int visible_height = 0;

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
                update_x11_hints ();
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

    private static Wl.RegistryListener registry_listener;
    private void init_panel () {
        get_surface ().layout.connect_after (() => {
            var new_full_height = main_box.get_height ();
            if (new_full_height != full_height) {
                full_height = new_full_height;

                if (panel != null) {
                    panel.set_size (-1, full_height);
                } else {
                    update_x11_hints ();
                }
            }

            unowned var item_manager = ItemManager.get_default ();
            var new_visible_width = item_manager.get_width ();
            var new_visible_height = item_manager.get_height ();

            if (new_visible_width != visible_width || new_visible_height != visible_height) {
                visible_width = new_visible_width;
                visible_height = new_visible_height;

                if (blur != null) {
                    blur.set_region (
                        0,
                        TOP_PADDING,
                        visible_width,
                        visible_height,
                        BORDER_RADIUS
                    );
                } else {
                    update_x11_hints ();
                }
            }
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
            update_x11_hints ();
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
        } else if (@interface == "io_elementary_pantheon_blur_manager_v1") {
            var blur_manager = wl_registry.bind<PantheonBlur.BlurManager> (name, ref PantheonBlur.BlurManager.iface, uint32.min (version, 1));
            unowned var surface = get_surface ();
            if (surface is Gdk.Wayland.Surface) {
                unowned var wl_surface = ((Gdk.Wayland.Surface) surface).get_wl_surface ();
                blur = blur_manager.get_blur (wl_surface);
            }
        }
    }

    private void update_x11_hints () {
        var display = Gdk.Display.get_default ();
        if (display is Gdk.X11.Display) {
            unowned var xdisplay = ((Gdk.X11.Display) display).get_xdisplay ();

            var window = ((Gdk.X11.Surface) get_surface ()).get_xid ();

            var prop = xdisplay.intern_atom ("_MUTTER_HINTS", false);

            var value = "anchor=8:hide-mode=%d:size=-1,%d:blur=%d,%d,%d,%d,%d".printf (
                settings.get_enum ("autohide-mode"),
                full_height,
                0,
                TOP_PADDING,
                visible_width,
                visible_height,
                BORDER_RADIUS
            );

            xdisplay.change_property (window, prop, X.XA_STRING, 8, 0, (uchar[]) value, value.length);
        }
    }
}
