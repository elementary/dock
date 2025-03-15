/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023-2025 elementary, Inc. (https://elementary.io)
 */

 public class Dock.ItemManager : Gtk.Fixed {
    private static Settings settings;

    private static GLib.Once<ItemManager> instance;
    public static unowned ItemManager get_default () {
        return instance.once (() => { return new ItemManager (); });
    }

    public Launcher? added_launcher { get; set; default = null; }

    private Adw.TimedAnimation resize_animation;
    private Gee.List<Launcher> launchers; // Only used to keep track of launcher indices
    private Gee.List<IconGroup> icon_groups; // Only used to keep track of icon group indices
    private DynamicWorkspaceIcon dynamic_workspace_item;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new Gee.ArrayList<Launcher> ();
        icon_groups = new Gee.ArrayList<IconGroup> ();

        // Idle is used here to because DynamicWorkspaceIcon depends on ItemManager
        Idle.add_once (() => {
            dynamic_workspace_item = new DynamicWorkspaceIcon ();
            add_item (dynamic_workspace_item);
        });

        overflow = VISIBLE;

        resize_animation = new Adw.TimedAnimation (
            this, 0, 0, 0,
            new Adw.CallbackAnimationTarget ((val) => {
                width_request = (int) val;
            })
        );

        resize_animation.done.connect (() => width_request = -1); //Reset otherwise we stay to big when the launcher icon size changes

        settings.changed.connect ((key) => {
            if (key == "icon-size") {
                reposition_items ();
            }
        });

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

        drop_target_file.leave.connect (() => {
            if (added_launcher != null) {
                //Without idle it crashes when the cursor is above the launcher
                Idle.add (() => {
                    added_launcher.app.pinned = false;
                    added_launcher = null;
                    return Source.REMOVE;
                });
            }
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

        WorkspaceSystem.get_default ().workspace_added.connect ((workspace) => {
            add_item (new IconGroup (workspace));
        });

        map.connect (() => {
            AppSystem.get_default ().load.begin ();
            WorkspaceSystem.get_default ().load.begin ();
        });
    }

    private void reposition_items () {
        int index = 0;
        foreach (var launcher in launchers) {
            position_item (launcher, ref index);
        }

        foreach (var icon_group in icon_groups) {
            position_item (icon_group, ref index);
        }

        position_item (dynamic_workspace_item, ref index);
    }

    private void position_item (BaseItem item, ref int index) {
        var position = get_launcher_size () * index;

        if (item.parent != this) {
            put (item, position, 0);
            item.current_pos = position;
        } else {
            item.animate_move (position);
        }

        index++;
    }

    private void add_launcher_via_dnd (Launcher launcher, int index) {
        launcher.removed.connect (remove_item);

        launchers.insert (index, launcher);
        reposition_items ();
        launcher.set_revealed (true);
    }

    private void add_item (BaseItem item) {
        item.removed.connect (remove_item);

        if (item is Launcher) {
            launchers.add ((Launcher) item);
        } else if (item is IconGroup) {
            icon_groups.add ((IconGroup) item);
        }

        resize_animation.easing = EASE_OUT_BACK;
        resize_animation.duration = Granite.TRANSITION_DURATION_OPEN;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.size * get_launcher_size ();
        resize_animation.play ();

        ulong reveal_cb = 0;
        reveal_cb = resize_animation.done.connect (() => {
            reposition_items ();
            item.set_revealed (true);
            resize_animation.disconnect (reveal_cb);
        });
    }

    private void remove_item (BaseItem item) {
        if (item is Launcher) {
            launchers.remove ((Launcher) item);
        } else if (item is IconGroup) {
            icon_groups.remove ((IconGroup) item);
        }

        item.set_revealed (false);
        item.revealed_done.connect (remove_finish);
    }

    private void remove_finish (BaseItem item) {
        // Temporarily set the width request to avoid flicker until the animation calls the callback for the first time
        width_request = get_width ();

        remove (item);
        reposition_items ();

        resize_animation.easing = EASE_IN_OUT_QUAD;
        resize_animation.duration = Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.size * get_launcher_size ();
        resize_animation.play ();

        item.cleanup ();
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        unowned Gee.List<BaseItem>? list = null;
        double offset = 0;
        if (source is Launcher) {
            list = launchers;
        } else if (source is IconGroup) {
            list = icon_groups;
            offset = launchers.size * get_launcher_size ();
        } else {
            warning ("Tried to move neither launcher nor icon group");
            return;
        }

        int source_index = list.index_of (source);

        source.animate_move ((get_launcher_size () * target_index) + offset);

        bool right = source_index > target_index;

        // Move the launchers located between the source and the target with an animation
        for (int i = (right ? target_index : (source_index + 1)); i <= (right ? source_index - 1 : target_index); i++) {
            list.get (i).animate_move ((right ? (i + 1) * get_launcher_size () : (i - 1) * get_launcher_size ()) + offset);
        }

        list.remove (source);
        list.insert (target_index, source);

        sync_pinned ();
    }

    public int get_index_for_launcher (BaseItem item) {
        if (item is Launcher) {
            return launchers.index_of ((Launcher) item);
        } else if (item is IconGroup) {
            return icon_groups.index_of ((IconGroup) item);
        }

        warning ("Tried to get index of neither launcher nor icon group");
        return 0;
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        foreach (var launcher in launchers) {
            if (launcher.app.pinned) {
                new_pinned_ids += launcher.app.app_info.get_id ();
            }
        }

        settings.set_strv ("launchers", new_pinned_ids);
    }

    public void launch (uint index) {
        if (index < 1 || index > launchers.size) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        launchers.get ((int) index - 1).app.launch (context);
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }
}
