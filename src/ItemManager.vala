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

    private DynamicWorkspaceIcon dynamic_workspace_item;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        var app_group = new ItemGroup (AppSystem.get_default ().apps, (obj) => new Launcher ((App) obj));

        var background_item = new BackgroundItem ();
        var background_group = new ItemGroup (background_item.group_model, (obj) => (BackgroundItem) obj);

        append (app_group);
        append (background_group);

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

            app = app_system.add_app_for_id (app_info.get_id ());

            for (var child = app_group.get_first_child (); child != null; child = child.get_next_sibling ()) {
                if (child is Launcher && child.app == app) {
                    added_launcher = (Launcher) child;
                    added_launcher.moving = true;
                    break;
                }
            }
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

        map.connect (() => {
            AppSystem.get_default ().load.begin ();
            background_item.load ();
        });
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        if (source is Launcher) {
            AppSystem.get_default ().reorder_app (source.app, target_index);
        } else {
            info ("Tried to move not a launcher");
        }
    }

    public void launch (uint index) {
        if (index < 1 || index > AppSystem.get_default ().apps.get_n_items ()) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        var app = (App) AppSystem.get_default ().apps.get_item (index - 1);
        app.launch (context);
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }
}
