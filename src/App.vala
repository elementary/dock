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

    public GLib.List<AppWindow> windows { get; private owned set; }

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
            } else if (windows.length () <= 1) {
                app_info.launch (null, context);
            } else if (LauncherManager.get_default ().desktop_integration != null) {
                LauncherManager.get_default ().desktop_integration.show_windows_for (app_info.get_id ());
            }
        } catch (Error e) {
            critical (e.message);
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
}
