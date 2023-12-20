/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Dock.LauncherManager : GLib.Object {
    public const string ACTION_GROUP_PREFIX = "app-actions";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    // First %s is the app id second %s the action name
    public const string LAUNCHER_ACTION_TEMPLATE = "%s.%s";
    // %s is the app id
    public const string LAUNCHER_PINNED_ACTION_TEMPLATE = "%s-pinned";

    private static Settings settings;

    private static GLib.Once<LauncherManager> instance;
    public static unowned LauncherManager get_default () {
        return instance.once (() => { return new LauncherManager (); });
    }

    public ListStore launchers { get; construct; }
    public SimpleActionGroup action_group { get; construct; }

    private Dock.DesktopIntegration desktop_integration;
    private GLib.HashTable<unowned string, Dock.Launcher> app_to_launcher;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new ListStore (typeof (Launcher));
        app_to_launcher = new GLib.HashTable<unowned string, Dock.Launcher> (str_hash, str_equal);
        action_group = new SimpleActionGroup ();

        GLib.Bus.get_proxy.begin<Dock.DesktopIntegration> (
            GLib.BusType.SESSION,
            "org.pantheon.gala",
            "/org/pantheon/gala/DesktopInterface",
            GLib.DBusProxyFlags.NONE,
            null,
            (obj, res) => {
            try {
                desktop_integration = GLib.Bus.get_proxy.end (res);
                desktop_integration.windows_changed.connect (sync_windows);

                sync_windows ();
            } catch (GLib.Error e) {
                critical (e.message);
            }
        });

        foreach (string app_id in settings.get_strv ("launchers")) {
            var app_info = new GLib.DesktopAppInfo (app_id);
            add_launcher (app_info, true);
        }
    }

    private unowned Launcher add_launcher (GLib.DesktopAppInfo app_info, bool pinned = false) {
        var launcher = new Launcher (app_info, pinned);

        unowned var app_id = app_info.get_id ();
        app_to_launcher.insert (app_id, launcher);
        launchers.append (launcher);

        var pinned_action = new SimpleAction.stateful (
            LAUNCHER_PINNED_ACTION_TEMPLATE.printf (app_id),
            null,
            new Variant.boolean (launcher.pinned)
        );
        pinned_action.change_state.connect ((new_state) => launcher.pinned = (bool) new_state);
        action_group.add_action (pinned_action);

        foreach (var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (LAUNCHER_ACTION_TEMPLATE.printf (app_id, action), null);
            simple_action.activate.connect (() => launcher.launch (action));
            action_group.add_action (simple_action);
        }

        launcher.notify["pinned"].connect (() => {
            pinned_action.set_state (launcher.pinned);
            sync_pinned ();
        });

        return app_to_launcher[app_id];
    }

    private void remove_launcher (Launcher launcher) {
        foreach (var action in action_group.list_actions ()) {
            if (action.has_prefix (launcher.app_info.get_id ())) {
                action_group.remove_action (action);
            }
        }

        launchers.remove (launcher.get_index ());
        app_to_launcher.remove (launcher.app_info.get_id ());
    }

    private void sync_windows () requires (desktop_integration != null) {
        DesktopIntegration.Window[] windows;
        try {
            windows = desktop_integration.get_windows ();
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var launcher_window_list = new GLib.HashTable<Launcher, GLib.List<AppWindow>> (direct_hash, direct_equal);
        foreach (unowned var window in windows) {
            unowned var app_id = window.properties["app-id"].get_string ();
            unowned Launcher? launcher = app_to_launcher[app_id];
            if (launcher == null) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                if (app_info == null) {
                    continue;
                }

                launcher = add_launcher (app_info);
            }

            AppWindow? app_window = launcher.find_window (window.uid);
            if (app_window == null) {
                app_window = new AppWindow (window.uid);
            }

            unowned var window_list = launcher_window_list.get (launcher);
            if (window_list == null) {
                var new_window_list = new GLib.List<AppWindow> ();
                new_window_list.append ((owned) app_window);
                launcher_window_list.insert (launcher, (owned) new_window_list);
            } else {
                window_list.append ((owned) app_window);
            }
        }

        foreach (var launcher in app_to_launcher.get_values ()) {
            var window_list = launcher_window_list.take (launcher);
            launcher.update_windows ((owned) window_list);
        }

        sync_pinned ();
    }

    public void move_launcher_after (Launcher source, int target_index) {
        int si = source.get_index ();

        launchers.remove (si);
        launchers.insert (target_index, source);

        var dir = si > target_index ? Gtk.DirectionType.RIGHT : Gtk.DirectionType.LEFT;

        for (int i = (dir == RIGHT ? target_index : si); i <= (dir == RIGHT ? si : target_index); i++) {
            ((Launcher) launchers.get_item (i)).animate_move (dir);
        }

        sync_pinned ();
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        for (int i = 0; i < launchers.get_n_items (); i++) {
            var current_child = (Launcher) launchers.get_item (i);

            if (current_child.pinned) {
                new_pinned_ids += current_child.app_info.get_id ();
            } else if (!current_child.pinned && current_child.windows.is_empty ()) {
                remove_launcher (current_child);
            }
        }

        var settings = new Settings ("io.elementary.dock");
        settings.set_strv ("launchers", new_pinned_ids);
    }
}
