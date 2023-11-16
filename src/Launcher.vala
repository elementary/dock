/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.Button {
    public GLib.DesktopAppInfo app_info { get; construct; }
    public bool pinned { get; set; }

    public GLib.List<AppWindow> windows { get; private owned set; }

    private static Settings settings;
    private static Gtk.CssProvider css_provider;

    private Gtk.PopoverMenu popover;

    public Launcher (GLib.DesktopAppInfo app_info) {
        Object (app_info: app_info);
    }

    class construct {
        set_css_name ("launcher");
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/dock/Launcher.css");

        settings = new Settings ("io.elementary.dock");
    }

    construct {
        windows = new GLib.List<AppWindow> ();
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var action_section = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            action_section.append (
                app_info.get_action_name (action),
                MainWindow.ACTION_PREFIX + MainWindow.LAUNCHER_ACTION_TEMPLATE.printf (app_info.get_id (), action)
            );
        }

        var pinned_section = new Menu ();
        pinned_section.append (
            _("Keep in Dock"),
            MainWindow.ACTION_PREFIX + MainWindow.LAUNCHER_PINNED_ACTION_TEMPLATE.printf (app_info.get_id ())
        );

        var model = new Menu ();
        if (action_section.get_n_items () > 0) {
            model.append_section (null, action_section);
        }
        model.append_section (null, pinned_section);

        popover = new Gtk.PopoverMenu.from_model (model) {
            autohide = true,
            position = TOP
        };
        popover.set_parent (this);

        var image = new Gtk.Image () {
            gicon = app_info.get_icon ()
        };
        image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        child = image;
        tooltip_text = app_info.get_display_name ();

        notify["pinned"].connect (() => ((MainWindow) get_root ()).sync_pinned ());

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect (popover.popup);

        clicked.connect (() => launch ());

        settings.bind ("icon-size", image, "pixel-size", DEFAULT);
    }

    ~Launcher () {
        popover.unparent ();
        popover.dispose ();
    }

    public void launch (string? action = null) {
        try {
            add_css_class ("bounce");

            var context = Gdk.Display.get_default ().get_app_launch_context ();
            context.set_timestamp (Gdk.CURRENT_TIME);

            if (action != null) {
                app_info.launch_action (action, context);
            } else {
                app_info.launch (null, context);
            }
        } catch (Error e) {
            critical (e.message);
        }

        Timeout.add (400, () => {
            remove_css_class ("bounce");

            return Source.REMOVE;
        });
    }

    public void update_windows (owned GLib.List<AppWindow>? new_windows) {
        if (new_windows == null) {
            windows = new GLib.List<AppWindow> ();
        } else {
            windows = (owned) new_windows;
        }
    }

    public AppWindow? find_window (uint64 window_uid) {
        unowned var found_win = windows.search<uint64> (window_uid, (win, searched_uid) => {
            if (win.uid == searched_uid) {
                return 0;
            } else if (win.uid > searched_uid) {
                return 1;
            } else {
                return -1;
            }
        });

        if (found_win != null) {
            return found_win.data;
        } else {
            return null;
        }
    }
}
