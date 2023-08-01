/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.Launcher : Gtk.Button {
    public GLib.DesktopAppInfo app_info { get; construct; }
    public bool pinned { get; set; }

    public GLib.List<AppWindow> windows { get; private owned set; }

    private static Gtk.CssProvider css_provider;

    private Gtk.Button close_button;
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
    }

    construct {
        windows = new GLib.List<AppWindow> ();
        get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var pinned_menu_item = new MenuItem (null, "win." + app_info.get_id () + "pinned");
        pinned_menu_item.set_attribute_value ("custom", "pinned-item");

        var close_menu_item = new MenuItem (null, null);
        close_menu_item.set_attribute_value ("custom", "close-item");

        var action_section = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            action_section.append (
                app_info.get_action_name (action),
                MainWindow.ACTION_PREFIX + MainWindow.LAUNCHER_ACTION_TEMPLATE.printf (app_info.get_id (), action)
            );
        }

        var model = new Menu ();
        model.append_item (pinned_menu_item);
        model.append_item (close_menu_item); // Placeholder, currently doesn't work
        if (action_section.get_n_items () > 0) {
            model.append_section (null, action_section);
        }

        var pinned_label = new Gtk.Label ("Keep in Dock") {
            xalign = 0,
            hexpand = true
        };

        var pinned_check_button = new Gtk.CheckButton ();

        var pinned_box = new Gtk.Box (HORIZONTAL, 3);
        pinned_box.append (pinned_label);
        pinned_box.append (pinned_check_button);

        var pinned_button = new Gtk.ToggleButton () {
            child = pinned_box
        };
        pinned_button.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        close_button = new Gtk.Button () {
            visible = false,
            child = new Gtk.Label (_("Close")) { halign = START }
        };
        close_button.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        popover = new Gtk.PopoverMenu.from_model (model) {
            position = TOP
        };
        popover.set_parent (this);
        popover.add_child (pinned_button, "pinned-item");
        popover.add_child (close_button, "close-item");

        var image = new Gtk.Image () {
            gicon = app_info.get_icon ()
        };
        image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        child = image;
        tooltip_text = app_info.get_display_name ();

        bind_property ("pinned", pinned_button, "active", BIDIRECTIONAL | SYNC_CREATE);
        pinned_button.bind_property ("active", pinned_check_button, "active", SYNC_CREATE);

        notify["pinned"].connect (() => ((MainWindow) get_root ()).sync_pinned ());

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect (popover.popup);

        clicked.connect (() => launch());

        close_button.clicked.connect (() => {
            // TODO
        });
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

        close_button.visible = !windows.is_empty ();
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
