/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.App : Object {
    public const string ACTION_GROUP_PREFIX = "app-actions";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string UNINSTALL_ACTION = "uninstall";
    public const string VIEW_ACTION = "view-in-appcenter";

    private const string SWITCHEROO_ACTION = "switcheroo";
    private const string APP_ACTION = "action.%s";

    public signal void launched () {
        if (!running && app_info.get_boolean ("StartupNotify")) {
            launching = true;

            Timeout.add_seconds (10, () => {
                launching = false;
                return Source.REMOVE;
            });
        }
    }

    public signal void removed ();

    public bool pinned { get; construct set; }
    public GLib.DesktopAppInfo app_info { get; construct; }

    public bool count_visible { get; private set; default = false; }
    public int64 current_count { get; private set; default = 0; }
    public bool progress_visible { get; set; default = false; }
    public double progress { get; set; default = 0; }
    public bool prefers_nondefault_gpu { get; private set; default = false; }
    public bool running { get { return windows.length > 0; } }
    public bool running_on_active_workspace {
        get {
            var active_workspace = WindowSystem.get_default ().active_workspace;
            foreach (var win in windows) {
                if (win.workspace_index == active_workspace) {
                    return true;
                }
            }

            return false;
        }
    }
    public bool launching { get; private set; default = false; }

    public SimpleActionGroup app_action_group { get; construct; }
    public Menu app_action_menu { get; construct; }

    public GLib.GenericArray<Window> windows { get; private owned set; } // Ordered by stacking order with topmost at 0

    private static Dock.SwitcherooControl switcheroo_control;
    private GLib.SimpleAction uninstall_action;
    private GLib.SimpleAction view_action;

    private string appstream_comp_id = "";

    public App (GLib.DesktopAppInfo app_info, bool pinned) {
        Object (app_info: app_info, pinned: pinned);
    }

    static construct {
        switcheroo_control = new Dock.SwitcherooControl ();
    }

    construct {
        windows = new GLib.GenericArray<Window> ();

        app_action_group = new SimpleActionGroup ();

        app_action_menu = new Menu ();
        foreach (var action in app_info.list_actions ()) {
            app_action_menu.append (app_info.get_action_name (action), ACTION_PREFIX + APP_ACTION.printf (action));
        }

        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            prefers_nondefault_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            var switcheroo_action = new SimpleAction (SWITCHEROO_ACTION, null);
            switcheroo_action.activate.connect (() => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);
                launch (context, null, false);
            });

            app_action_group.add_action (switcheroo_action);

            app_action_menu.append (
                _("Open with %s Graphics").printf (switcheroo_control.get_gpu_name (!prefers_nondefault_gpu)),
                ACTION_PREFIX + SWITCHEROO_ACTION
            );
        }

        foreach (var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (APP_ACTION.printf (action), null);
            simple_action.activate.connect ((instance, variant) => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                // Don't use the local action to avoid memory leaks
                var split = instance.name.split (".");
                launch (context, split[1]);
            });
            app_action_group.add_action (simple_action);
        }

        if (Environment.find_program_in_path ("io.elementary.appcenter") != null) {
            uninstall_action = new SimpleAction (UNINSTALL_ACTION, null);
            uninstall_action.activate.connect (action_uninstall);

            view_action = new SimpleAction (VIEW_ACTION, null);
            view_action.activate.connect (open_in_appcenter);

            app_action_group.add_action (uninstall_action);
            app_action_group.add_action (view_action);

            var appcenter = Dock.AppCenter.get_default ();
            appcenter.notify["dbus"].connect (() => on_appcenter_dbus_changed.begin ());
            on_appcenter_dbus_changed.begin ();
        }

        notify["pinned"].connect (() => {
            check_remove ();
            ItemManager.get_default ().sync_pinned ();
        });

        WindowSystem.get_default ().notify["active-workspace"].connect (() => {
            notify_property ("running-on-active-workspace");
        });
    }

    public void launch (AppLaunchContext context, string? action = null, bool? use_preferred_gpu = true) {
        launched ();

        if (use_preferred_gpu) {
            switcheroo_control.apply_gpu_environment (context, !prefers_nondefault_gpu);
        } else {
            switcheroo_control.apply_gpu_environment (context, prefers_nondefault_gpu);
        }

        context.launched.connect (start_systemd_scope);

        try {
            if (action != null) {
                app_info.launch_action (action, context);
            } else if (windows.length == 0) {
                app_info.launch (null, context);
            } else if (windows.length == 1) {
                WindowSystem.get_default ().desktop_integration.focus_window.begin (windows[0].uid);
            } else if (WindowSystem.get_default ().desktop_integration != null) {
                WindowSystem.get_default ().desktop_integration.show_windows_for.begin (app_info.get_id ());
            }
        } catch (Error e) {
            critical (e.message);
        }
    }

    private async void start_systemd_scope (AppLaunchContext context, GLib.AppInfo appinfo, Variant platform_data) {
        int pid;
        if (!platform_data.lookup ("pid", "i", out pid)) {
            return;
        }

        var app_name = appinfo.get_id () ?? appinfo.get_executable ();
        // if we got a path, use the binary name only
        if (app_name.has_prefix ("/")) {
            app_name = Path.get_basename (app_name);
        } else if (app_name.has_suffix (".desktop")) {
            app_name = app_name.substring (0, app_name.length - 8);
        }

        DBusConnection connection;
        try {
            connection = Bus.get_sync (SESSION, null);
        } catch (Error e) {
            critical ("Couldn't connect to DBus: %s", e.message);
            return;
        }

        // If an app is dbus activatable, we don't launch it directly
        // dbus-daemon launches it for us, so we can't get pid from platform_data
        if (appinfo is DesktopAppInfo && ((DesktopAppInfo) appinfo).get_boolean ("DBusActivatable")) {
            try {
                var reply = connection.call_sync (
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    "GetConnectionUnixProcessID",
                    new Variant ("(s)", app_name),
                    new VariantType ("(u)"),
                    NONE,
                    1000,
                    null
                );

                reply.get ("(u)", out pid);
            } catch (Error e) {
                critical ("Couldn't get pid of dbus activatable app: %s", e.message);
                return;
            }
        }

        var string_builder = new StringBuilder.sized (app_name.length);
        for (var i = 0; i < app_name.length; i++) {
            var c = app_name[i];
            if (c.isalnum () || c == ':' || c == '_' || c == '.') {
                string_builder.append_c (c);
            } else {
                string_builder.append_printf ("\\x%02x", c);
            }
        }

        var builder = new VariantBuilder (new VariantType ("(ssa(sv)a(sa(sv)))"));
        builder.add ("s", "app-pantheon-%s-%d.scope".printf (string_builder.free_and_steal (), pid));
        builder.add ("s", "fail");

        builder.open (new VariantType ("a(sv)"));
        builder.add ("(sv)", "Description", new Variant.string ("Application launched by %s".printf (GLib.Application.get_default ().application_id)));
        builder.add ("(sv)", "PIDs", new Variant.array (VariantType.UINT32, { (uint32) pid }));

        // Default to let systemd garbage collect failed applications we launched.
        builder.add ("(sv)", "CollectMode", new Variant.string ("inactive-or-failed"));
        builder.close ();

        builder.open (new VariantType ("a(sa(sv))"));
        builder.close ();

        try {
            connection.call_sync (
                "org.freedesktop.systemd1",
                "/org/freedesktop/systemd1",
                "org.freedesktop.systemd1.Manager",
                "StartTransientUnit",
                builder.end (),
                new VariantType ("(o)"),
                NO_AUTO_START,
                1000,
                null
            );
        } catch (Error e) {
            warning ("Couldn't put an app into Systemd scope: %s", e.message);
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

    private void check_remove () {
        if (!pinned && !running) {
            removed ();
        }
    }

    public void update_windows (GLib.GenericArray<Window>? new_windows) {
        if (new_windows == null) {
            windows = new GLib.GenericArray<Window> ();
        } else {
            windows = new_windows;
        }

        notify_property ("running-on-active-workspace");
        notify_property ("running");

        if (launching && running) {
            launching = false;
        }

        check_remove ();
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

    private Window[] current_windows;
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

        WindowSystem.get_default ().desktop_integration.focus_window.begin (current_windows[current_index].uid);

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
            yield AppSystem.get_default ().sync_windows (); // Get the current stacking order
            current_index = windows.length > 1 && windows[0].has_focus ? 1 : 0;
            current_windows = {};
            foreach (var window in windows) {
                current_windows += window;
            }
        }

        timer_id = Timeout.add_seconds (2, () => {
            timer_id = 0;
            current_windows = null;
            return Source.REMOVE;
        });
    }

    private void action_uninstall () {
        var appcenter = Dock.AppCenter.get_default ();
        if (appcenter.dbus == null || appstream_comp_id == "") {
            return;
        }

        appcenter.dbus.uninstall.begin (appstream_comp_id, (obj, res) => {
            try {
                appcenter.dbus.uninstall.end (res);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        });
    }

    private void open_in_appcenter () {
        AppInfo.launch_default_for_uri_async.begin ("appstream://" + appstream_comp_id, null, null, (obj, res) => {
            try {
                AppInfo.launch_default_for_uri_async.end (res);
            } catch (Error error) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Unable to open %s in AppCenter".printf (app_info.get_display_name ()),
                    "",
                    "dialog-error",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (error.message);
                message_dialog.response.connect (message_dialog.destroy);
                message_dialog.present ();
            }
        });
    }

    private async void on_appcenter_dbus_changed () {
        var appcenter = Dock.AppCenter.get_default ();
        if (appcenter.dbus != null) {
            try {
                appstream_comp_id = yield appcenter.dbus.get_component_from_desktop_id (app_info.get_id ());
            } catch (GLib.Error e) {
                appstream_comp_id = "";
                warning (e.message);
            }
        } else {
            appstream_comp_id = "";
        }

        uninstall_action.set_enabled (appstream_comp_id != "");
        view_action.set_enabled (appstream_comp_id != "");
    }
}
