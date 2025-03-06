/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.MainWindow : Granite.BlurSurface, Gtk.ApplicationWindow {
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
                update_real_x11_hints ();
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

    private void init_panel () {
        if (is_wayland ()) {
            init_wayland (registry_handle_global);
        } else {
            update_real_x11_hints ();
        }

        get_surface ().layout.connect_after (() => {
            var new_full_height = main_box.get_height ();

            if (new_full_height != full_height) {
                full_height = new_full_height;

                if (panel != null) {
                    panel.set_size (-1, full_height);
                } else {
                    update_real_x11_hints ();
                }

            }

            unowned var item_manager = ItemManager.get_default ();
            var new_visible_width = item_manager.get_width ();
            var new_visible_height = item_manager.get_height ();

            if (new_visible_width != visible_width || new_visible_height != visible_height) {
                visible_width = new_visible_width;
                visible_height = new_visible_height;

                if (is_wayland ()) {
                    request_blur_wayland (
                        0,
                        TOP_PADDING,
                        visible_width,
                        visible_height,
                        BORDER_RADIUS
                    );
                } else {
                    update_real_x11_hints ();
                }
            }
        });
    }

    public void registry_handle_global (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
        panel_registry_handle_global (wl_registry, name, @interface, version);
        blur_registry_handle_global (wl_registry, name, @interface, version);
    }

    public void panel_registry_handle_global (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
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

    private void update_real_x11_hints () {
        update_x11_hints (get_x11_panel_hints () + get_real_x11_blur_hints ());
    }

    private string get_x11_panel_hints () {
        return "anchor=8:hide-mode=%d:size=-1,%d:".printf (settings.get_enum ("autohide-mode"), full_height);
    }

    private string get_real_x11_blur_hints () {
        return get_x11_blur_hints (
            0,
            TOP_PADDING,
            visible_width,
            visible_height,
            BORDER_RADIUS
        );
    }
}
