/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

 public class Dock.LauncherManager : Gtk.Fixed {
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

    private SimpleActionGroup action_group;
    private List<Launcher> launchers; //Only used to keep track of launcher indices
    private Dock.DesktopIntegration desktop_integration;
    private GLib.HashTable<unowned string, Dock.Launcher> app_to_launcher;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new List<Launcher> ();
        app_to_launcher = new GLib.HashTable<unowned string, Dock.Launcher> (str_hash, str_equal);
        action_group = new SimpleActionGroup ();
        insert_action_group (ACTION_GROUP_PREFIX, action_group);

        height_request = get_launcher_size ();

        settings.changed.connect ((key) => {
            if (key == "icon-size") {
                update_icon_size ();
            }
        });

        Idle.add (() => {
            foreach (string app_id in settings.get_strv ("launchers")) {
                var app_info = new GLib.DesktopAppInfo (app_id);
                add_launcher (app_info, true);
            }

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
        });
    }

    private void update_icon_size () {
        width_request = (int) launchers.length () * get_launcher_size ();
        height_request = get_launcher_size ();
        for (int i = 0; i < launchers.length (); i++) {
            move (launchers.nth_data (i), i * get_launcher_size (), 0);
        }
    }

    private int get_launcher_size () {
        return settings.get_int ("icon-size") + 12;
    }

    private unowned Launcher add_launcher (GLib.DesktopAppInfo app_info, bool pinned = false) {
        var launcher = new Launcher (app_info, pinned);

        unowned var app_id = app_info.get_id ();
        app_to_launcher.insert (app_id, launcher);
        launchers.append (launcher);
        put (launcher, width_request, 0);
        width_request = width_request + get_launcher_size ();

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

        for (int i = launchers.index (launcher); i < launchers.length (); i++) {
            move (launchers.nth_data (i), (i - 1) * get_launcher_size (), 0);
        }
        launchers.remove (launcher);
        app_to_launcher.remove (launcher.app_info.get_id ());
        remove (launcher);
        width_request -= get_launcher_size ();
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
        int source_index = launchers.index (source);

        move (source, get_launcher_size () * target_index, 0);

        bool right = source_index > target_index;

        for (int i = (right ? target_index : (source_index + 1)); i <= (right ? source_index - 1 : target_index); i++) {
            animate_move (launchers.nth_data (i), i, right);
        }

        launchers.remove (source);
        launchers.insert (source, target_index);

        sync_pinned ();
    }

    private void animate_move (Launcher widget, int index, bool right) {
        var animation_target = new Adw.CallbackAnimationTarget ((val) => {
            move (widget, val, 0);
        });

        //TODO: Which easing should we use?
        var timed_animation = new Adw.TimedAnimation (
            widget, 
            index * get_launcher_size (), 
            right ? index * get_launcher_size () + get_launcher_size () : index * get_launcher_size () - get_launcher_size (), 
            300, 
            animation_target
        );
        timed_animation.play ();
    }

    public int get_index_for_launcher (Launcher launcher) {
        return launchers.index (launcher);
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        foreach (var launcher in launchers) {
            if (launcher.pinned) {
                new_pinned_ids += launcher.app_info.get_id ();
            } else if (!launcher.pinned && launcher.windows.is_empty ()) {
                remove_launcher (launcher);
            }
        }

        var settings = new Settings ("io.elementary.dock");
        settings.set_strv ("launchers", new_pinned_ids);
    }
}