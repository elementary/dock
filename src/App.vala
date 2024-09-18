/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Dock.App : Object {
    private const string ACTION_GROUP_PREFIX = "app-actions";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string PINNED_ACTION = "pinned";
    private const string SWITCHEROO_ACTION = "switcheroo";
    private const string APP_ACTION = "action.%s";

    public signal void launching ();

    public bool pinned { get; construct set; }
    public GLib.DesktopAppInfo app_info { get; construct; }

    public bool count_visible { get; private set; default = false; }
    public int64 current_count { get; private set; default = 0; }
    public bool progress_visible { get; set; default = false; }
    public double progress { get; set; default = 0; }
    public bool prefers_nondefault_gpu { get; private set; default = false; }
    public bool running { get { return windows.size > 0; } }
    public bool running_on_active_workspace {
        get {
            foreach (var win in windows) {
                if (win.on_active_workspace) {
                    return true;
                }
            }

            return false;
        }
    }

    public SimpleActionGroup action_group { get; construct; }
    public Menu menu_model { get; construct; }

    public Gee.List<AppWindow> windows { get; private owned set; } //Ordered by stacking order with topmost at 0

    private static Dock.SwitcherooControl switcheroo_control;

    private SimpleAction pinned_action;

    public App (GLib.DesktopAppInfo app_info, bool pinned) {
        Object (app_info: app_info, pinned: pinned);
    }

    static construct {
        switcheroo_control = new Dock.SwitcherooControl ();
    }

    construct {
        windows = new Gee.LinkedList<AppWindow> ();

        action_group = new SimpleActionGroup ();

        var action_section = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            action_section.append (app_info.get_action_name (action), ACTION_PREFIX + APP_ACTION.printf (action));
        }

        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            prefers_nondefault_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            var switcheroo_action = new SimpleAction (SWITCHEROO_ACTION, null);
            switcheroo_action.activate.connect (() => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);
                launch (context, null, false);
            });

            action_group.add_action (switcheroo_action);

            action_section.append (
                _("Open with %s Graphics").printf (switcheroo_control.get_gpu_name (!prefers_nondefault_gpu)),
                ACTION_PREFIX + SWITCHEROO_ACTION
            );
        }

        var pinned_section = new Menu ();
        pinned_section.append (_("Keep in Dock"), ACTION_PREFIX + PINNED_ACTION);

        menu_model = new Menu ();
        if (action_section.get_n_items () > 0) {
            menu_model.append_section (null, action_section);
        }
        menu_model.append_section (null, pinned_section);

        var launcher_manager = LauncherManager.get_default ();

        pinned_action = new SimpleAction.stateful (PINNED_ACTION, null, new Variant.boolean (pinned));
        pinned_action.change_state.connect ((new_state) => pinned = (bool) new_state);
        action_group.add_action (pinned_action);

        foreach (var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (APP_ACTION.printf (action), null);
            simple_action.activate.connect ((instance, variant) => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                // Don't use the local action to avoid memory leaks
                var split = instance.name.split (".");
                launch (context, split[1]);
            });
            action_group.add_action (simple_action);
        }

        notify["pinned"].connect (() => {
            pinned_action.set_state (pinned);
            LauncherManager.get_default ().sync_pinned ();
        });
    }

    public void launch (AppLaunchContext context, string? action = null, bool? use_preferred_gpu = true) {
        launching ();

        if (use_preferred_gpu) {
            switcheroo_control.apply_gpu_environment (context, !prefers_nondefault_gpu);
        } else {
            switcheroo_control.apply_gpu_environment (context, prefers_nondefault_gpu);
        }

        try {
            if (action != null) {
                app_info.launch_action (action, context);
            } else if (windows.size == 0) {
                app_info.launch (null, context);
            } else if (windows.size == 1) {
                LauncherManager.get_default ().desktop_integration.focus_window.begin (windows.first ().uid);
            } else if (LauncherManager.get_default ().desktop_integration != null) {
                LauncherManager.get_default ().desktop_integration.show_windows_for.begin (app_info.get_id ());
            }
        } catch (Error e) {
            critical (e.message);
        }
    }

    public bool launch_new_instance (AppLaunchContext context) {
        // Treat this as a string to distinguish between false and null
        var single_main_window = app_info.get_string ("SingleMainWindow");
        if (single_main_window == "true") {
            return false;
        }

        switcheroo_control.apply_gpu_environment (context, !prefers_nondefault_gpu);

        if ("new-window" in app_info.list_actions ()) {
            app_info.launch_action ("new-window", context);
            return true;
        }

        if ("NewWindow" in app_info.list_actions ()) {
            app_info.launch_action ("NewWindow", context);
            return true;
        }

        if (single_main_window == "false") {
            try {
                app_info.launch (null, context);
                return true;
            } catch (Error e) {
                critical (e.message);
            }
        }

        return false;
    }

    public void update_windows (Gee.List<AppWindow>? new_windows) {
        if (new_windows == null) {
            windows = new Gee.LinkedList<AppWindow> ();
        } else {
            windows = new_windows;
        }

        notify_property ("running-on-active-workspace");
        notify_property ("running");
    }

    public AppWindow? find_window (uint64 window_uid) {
        var found_win = windows.first_match ((win) => {
            return win.uid == window_uid;
        });

        if (found_win != null) {
            return found_win;
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
            current_index = windows.size > 1 && windows.first ().has_focus ? 1 : 0;
            current_windows = {};
            foreach (AppWindow window in windows) {
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
