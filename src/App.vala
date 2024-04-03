/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Dock.App : Object {
    private const string ACTION_GROUP_PREFIX = "app-actions";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string PINNED_ACTION = "pinned";
    private const string APP_ACTION = "action.%s";

    public signal void launching ();

    public bool pinned { get; construct set; }
    public GLib.DesktopAppInfo app_info { get; construct; }

    public bool count_visible { get; private set; default = false; }
    public int64 current_count { get; private set; default = 0; }
    public bool progress_visible { get; set; default = false; }
    public double progress { get; set; default = 0; }

    public SimpleActionGroup action_group { get; construct; }
    public Menu menu_model { get; construct; }

    public GLib.List<AppWindow> windows { get; private owned set; } //Ordered by stacking order with topmost at 0

    public App (GLib.DesktopAppInfo app_info, bool pinned) {
        Object (app_info: app_info, pinned: pinned);
    }

    construct {
        windows = new GLib.List<AppWindow> ();

        var action_section = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            action_section.append (app_info.get_action_name (action), ACTION_PREFIX + APP_ACTION.printf (action));
        }

        var pinned_section = new Menu ();
        pinned_section.append (_("Keep in Dock"), ACTION_PREFIX + PINNED_ACTION);

        menu_model = new Menu ();
        if (action_section.get_n_items () > 0) {
            menu_model.append_section (null, action_section);
        }
        menu_model.append_section (null, pinned_section);

        var launcher_manager = LauncherManager.get_default ();

        action_group = new SimpleActionGroup ();

        var pinned_action = new SimpleAction.stateful (PINNED_ACTION, null, new Variant.boolean (pinned));
        pinned_action.change_state.connect ((new_state) => pinned = (bool) new_state);
        action_group.add_action (pinned_action);

        foreach (var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (APP_ACTION.printf (action), null);
            simple_action.activate.connect (() => launch (action));
            action_group.add_action (simple_action);
        }

        notify["pinned"].connect (() => {
            pinned_action.set_state (pinned);
            launcher_manager.sync_pinned ();
        });
    }

    public void launch (string? action = null) {
        launching ();

        try {
            var context = Gdk.Display.get_default ().get_app_launch_context ();
            context.set_timestamp (Gdk.CURRENT_TIME);

            if (action != null) {
                app_info.launch_action (action, context);
            } else if (windows.length () == 0) {
                app_info.launch (null, context);
            } else if (windows.length () == 1) {
                LauncherManager.get_default ().desktop_integration.focus_window.begin (windows.first ().data.uid);
            } else if (LauncherManager.get_default ().desktop_integration != null) {
                LauncherManager.get_default ().desktop_integration.show_windows_for.begin (app_info.get_id ());
            }
        } catch (Error e) {
            critical (e.message);
        }
    }

    public void launch_new_instance () {
        var single_main_window = app_info.get_string ("SingleMainWindow");
        if (single_main_window == "true") {
            return;
        }

        var actions = app_info.list_actions ();
        var has_new_window_action = "new-window" in app_info.list_actions ();

        if (single_main_window == "false" || has_new_window_action) {
            try {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                if (has_new_window_action) {
                    app_info.launch_action ("new-window", context);
                } else {
                    app_info.launch (null, context);
                }
            } catch (Error e) {
                critical (e.message);
            }
        } else {
            Gdk.Display.get_default ().beep ();
        }
    }

    public void update_windows (owned GLib.List<AppWindow>? new_windows) {
        if (new_windows == null) {
            windows = new GLib.List<AppWindow> ();
        } else {
            windows = (owned) new_windows;
        }
    }

    public AppWindow? find_window (uint64 window_uid) {
        unowned var found_win = windows.search<uint64?> (window_uid, (win, searched_uid) =>
            win.uid == searched_uid ? 0 : win.uid > searched_uid ? 1 : -1
        );

        if (found_win != null) {
            return found_win.data;
        } else {
            return null;
        }
    }

    public void perform_unity_update (VariantIter prop_iter) {
        string prop_key;
        Variant prop_value;
        while (prop_iter.next ("{sv}", out prop_key, out prop_value)) {
            switch (prop_key) {
                case "count":
                    current_count = prop_value.get_int64 ();
                    break;
                case "count-visible":
                    count_visible = prop_value.get_boolean ();
                    break;
                case "progress":
                    progress = prop_value.get_double ();
                    break;
                case "progress-visible":
                    progress_visible = prop_value.get_boolean ();
                    break;
            }
        }
    }

    public void remove_launcher_entry () {
        count_visible = false;
        current_count = 0;
        progress_visible = false;
        progress = 0;
    }

    private AppWindow[] current_windows;
    private uint current_index;
    private uint timer_id = 0;
    private bool should_wait = false;

    public async void next_window (bool backwards) {
        if (should_wait) {
            return;
        }
        should_wait = true;

        if (backwards) {
            current_index = current_index <= 0 ? current_windows.length - 1 : current_index - 1;
        } else {
            current_index = current_index >= current_windows.length - 1 ? 0 : current_index + 1;
        }

        yield start_cycle ();

        if (current_windows.length == 0) {
            return;
        }

        LauncherManager.get_default ().desktop_integration.focus_window.begin (current_windows[current_index].uid);

        // Throttle the scroll for performance and better visibility of the windows
        Timeout.add (250, () => {
            should_wait = false;
            return Source.REMOVE;
        });
    }

    // The windows list is always sorted by stacking but when cycling we need to know the order
    // from when the cycling was started for the duration of the cycling
    private async void start_cycle () {
        if (timer_id != 0) {
            Source.remove (timer_id);
        } else {
            yield LauncherManager.get_default ().sync_windows (); // Get the current stacking order
            current_index = windows.length () > 1 && windows.first ().data.has_focus ? 1 : 0;
            current_windows = {};
            foreach (weak AppWindow window in windows) {
                current_windows += window;
            }
        }

        timer_id = Timeout.add_seconds (2, () => {
            timer_id = 0;
            current_windows = null;
            return Source.REMOVE;
        });
    }
}
