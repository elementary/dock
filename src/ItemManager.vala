/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023-2025 elementary, Inc. (https://elementary.io)
 */

 public class Dock.ItemManager : Gtk.Box {
    private static Settings settings;

    private static GLib.Once<ItemManager> instance;
    public static unowned ItemManager get_default () {
        return instance.once (() => { return new ItemManager (); });
    }

    public Launcher? added_launcher { get; set; default = null; }

    private ListStore launchers;
    private BackgroundItem background_item;
    private ListStore icon_groups; // Only used to keep track of icon group indices
    private DynamicWorkspaceIcon dynamic_workspace_item;

#if WORKSPACE_SWITCHER
    private Gtk.Separator separator;
#endif

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new ListStore (typeof (Launcher));

        background_item = new BackgroundItem ();
        background_item.apps_appeared.connect (add_item);

        icon_groups = new ListStore (typeof (WorkspaceIconGroup));

#if WORKSPACE_SWITCHER
        dynamic_workspace_item = new DynamicWorkspaceIcon ();

        separator = new Gtk.Separator (VERTICAL) {
            valign = START,
            margin_top = Launcher.PADDING,
        };
        settings.bind ("icon-size", separator, "height-request", GET);
#endif

        append (new ItemGroup (launchers));
        append (background_item);
#if WORKSPACE_SWITCHER
        append (separator);
        append (new ItemGroup (icon_groups));
        append (dynamic_workspace_item);
#endif
        overflow = VISIBLE;

        var drop_target_file = new Gtk.DropTarget (typeof (File), COPY) {
            preload = true
        };
        add_controller (drop_target_file);

        double drop_x, drop_y;
        drop_target_file.enter.connect ((x, y) => {
            drop_x = x;
            drop_y = y;
            return COPY;
        });

        drop_target_file.notify["value"].connect (() => {
            if (drop_target_file.get_value () == null) {
                return;
            }

            if (drop_target_file.get_value ().get_object () == null) {
                return;
            }

            if (!(drop_target_file.get_value ().get_object () is File)) {
                return;
            }

            var file = (File) drop_target_file.get_value ().get_object ();
            var app_info = new DesktopAppInfo.from_filename (file.get_path ());

            if (app_info == null) {
                return;
            }

            var app_system = AppSystem.get_default ();

            var app = app_system.get_app (app_info.get_id ());
            if (app != null) {
                app.pinned = true;
                drop_target_file.reject ();
                return;
            }

            app_system.add_app_for_id (app_info.get_id ());
        });

        BaseItem? current_base_item = null;
        drop_target_file.motion.connect ((x, y) => {
            if (added_launcher == null) {
                current_base_item = null;
                return COPY;
            }

            var base_item = (BaseItem) pick (x, y, DEFAULT).get_ancestor (typeof (BaseItem));
            if (base_item == current_base_item) {
                return COPY;
            }

            current_base_item = base_item;

            if (base_item != null) {
                Graphene.Point translated;
                compute_point (base_item, { (float) x, (float) y}, out translated);
                base_item.calculate_dnd_move (added_launcher, translated.x, translated.y);
            }

            return COPY;
        });

        drop_target_file.leave.connect (() => {
            current_base_item = null;

            if (added_launcher != null) {
                //Without idle it crashes when the cursor is above the launcher
                Idle.add (() => {
                    added_launcher.app.pinned = false;
                    added_launcher = null;
                    return Source.REMOVE;
                });
            }
        });

        drop_target_file.drop.connect (() => {
            if (added_launcher != null) {
                added_launcher.moving = false;
                added_launcher = null;
                return true;
            }
            return false;
        });

        AppSystem.get_default ().app_added.connect ((app) => {
            var launcher = new Launcher (app);

            if (drop_target_file.get_value () != null && added_launcher == null) { // The launcher is being added via dnd from wingpanel
                var position = (int) Math.round (drop_x / get_launcher_size ());
                added_launcher = launcher;
                launcher.moving = true;

                add_launcher_via_dnd (launcher, position);
                return;
            }

            add_item (launcher);
        });

#if WORKSPACE_SWITCHER
        WorkspaceSystem.get_default ().workspace_added.connect ((workspace) => {
            add_item (new WorkspaceIconGroup (workspace));
        });
#endif

        map.connect (() => {
            AppSystem.get_default ().load.begin ();
            background_item.load ();
#if WORKSPACE_SWITCHER
            WorkspaceSystem.get_default ().load.begin ();
#endif
        });
    }

    private void add_launcher_via_dnd (Launcher launcher, int index) {
        launcher.removed.connect (remove_item);

        launchers.insert (index, launcher);
        sync_pinned ();
    }

    private void add_item (BaseItem item) {
        item.removed.connect (remove_item);

        if (item is Launcher) {
            launchers.append (item);
            sync_pinned ();
        } else if (item is WorkspaceIconGroup) {
            icon_groups.append (item);
        }
    }

    private void remove_item (BaseItem item) {
        ListStore store;
        if (item is Launcher) {
            store = launchers;
        } else if (item is WorkspaceIconGroup) {
            store = icon_groups;
        } else {
            return;
        }

        uint index;
        if (store.find (item, out index)) {
            store.remove (index);
        }

        item.removed.disconnect (remove_item);
        item.cleanup ();
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        ListStore list;
        if (source is Launcher) {
            list = launchers;
        } else if (source is WorkspaceIconGroup) {
            list = icon_groups;
        } else {
            warning ("Tried to move neither launcher nor icon group");
            return;
        }

        var source_index = get_index_for_launcher (source);

        list.remove ((uint) source_index);
        list.insert (target_index, source);

        sync_pinned ();
    }

    public int get_index_for_launcher (BaseItem item) {
        if (item is Launcher) {
            uint index;
            if (launchers.find ((Launcher) item, out index)) {
                return (int) index;
            }

            return 0;
        } else if (item is WorkspaceIconGroup) {
            uint index;
            if (icon_groups.find ((WorkspaceIconGroup) item, out index)) {
                return (int) index;
            }

            return 0;
        } else if (item == dynamic_workspace_item) { //treat dynamic workspace icon as last icon group
            return (int) icon_groups.get_n_items ();
        }

        warning ("Tried to get index of neither launcher nor icon group");
        return 0;
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        for (uint i = 0; i < launchers.get_n_items (); i++) {
            var launcher = (Launcher) launchers.get_item (i);
            if (launcher.app.pinned) {
                new_pinned_ids += launcher.app.app_info.get_id ();
            }
        }

        settings.set_strv ("launchers", new_pinned_ids);
    }

    public void launch (uint index) {
        if (index < 1 || index > launchers.get_n_items ()) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        var launcher = (Launcher) launchers.get_item (index - 1);
        launcher.app.launch (context);
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }
}
