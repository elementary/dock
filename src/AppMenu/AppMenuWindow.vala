/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.AppMenuWindow : Gtk.Window {

    private const string STYLE = """
        .transparent { background: transparent; }
        .overlay-window {
            background: transparent;
        }

        .overlay-background {
            background: alpha(@accent_color, 0.18);
            border: 1px solid alpha(white, 0.12);
            border-radius: 0;
        }

        .overlay-card {
            background: alpha(black, 0.45);
            border: 1px solid alpha(white, 0.15);
            border-radius: 12px;
            padding: 32px 40px;
        }

        .overlay-title {
            font-size: 28px;
            font-weight: 700;
            color: white;
            text-shadow: 0 2px 12px alpha(black, 0.8);
        }

        .overlay-subtitle {
            font-size: 14px;
            color: alpha(white, 0.72);
            margin-top: 4px;
        }

        .overlay-close {
            background: alpha(white, 0.1);
            border: 1px solid alpha(white, 0.2);
            border-radius: 6px;
            color: white;
            padding: 8px 20px;
            font-size: 13px;
            font-weight: 600;
            transition: background 200ms ease;
        }

        .overlay-close:hover {
            background: alpha(white, 0.2);
        }

        .overlay-close:active {
            background: alpha(white, 0.08);
        }

        .overlay-hint {
            font-size: 12px;
            color: alpha(white, 0.45);
            margin-top: 24px;
        }

        .separator-line {
            background: alpha(white, 0.12);
            min-height: 1px;
            margin: 20px 0;
        }
    """;

    construct {
        // ── Window setup ─────────────────────────────────────────────────
        // Remove decorations and make the window itself transparent
        decorated = false;
        resizable = false;
        set_default_size (-1, -1);
        add_css_class("transparent");

        // -- Enable transparency ------------------------------------------
        //realize.connect(() => {
            var surface = get_surface();
            if (surface != null) {
                // null region = entire surface is transparent/blended
                surface.set_opaque_region(null);
            }
        //});
        // ── CSS ──────────────────────────────────────────────────────────
        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (STYLE);
        } catch (Error e) {
            warning ("CSS error: %s", e.message);
        }
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        // ── Full-screen background overlay ───────────────────────────────
        var bg_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        bg_box.add_css_class ("overlay-background");
        bg_box.halign = Gtk.Align.FILL;
        bg_box.valign = Gtk.Align.FILL;
        bg_box.hexpand = true;
        bg_box.vexpand = true;

        // ── Centre card ──────────────────────────────────────────────────
        var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        container.add_css_class ("overlay-card");
        container.halign = Gtk.Align.CENTER;
        container.valign = Gtk.Align.CENTER;
        container.hexpand = true;
        container.vexpand = true;

        // Search Bar
        var search_bar = new Gtk.Label ("Applications Menu");

        // Subtitle
        var app_grid = new Gtk.Grid ();

        // Separator
        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.add_css_class ("separator-line");

        // Hint
        var hint = new Gtk.Label ("Press Escape or click Close to dismiss.");
        hint.add_css_class ("overlay-hint");
        hint.halign = Gtk.Align.CENTER;

        container.append (search_bar);
        container.append (app_grid);
        container.append (separator);
        container.append (hint);


        // ── Key bindings ─────────────────────────────────────────────────
        /*key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                destroy ();
                return true;
            }
            return false;
        });*/

        bg_box.append (container);
        set_child (bg_box);

        // Go fullscreen after everything is wired up
        fullscreen ();
    }
}
