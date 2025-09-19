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
    private GLib.GenericArray<Launcher> launchers; // Only used to keep track of launcher indices
    private BackgroundItem background_item;
    private GLib.GenericArray<WorkspaceIconGroup> icon_groups; // Only used to keep track of icon group indices
    private DynamicWorkspaceIcon dynamic_workspace_item;

#if WORKSPACE_SWITCHER
    private Gtk.Separator separator;
#endif

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new GLib.GenericArray<Launcher> ();

        background_item = new BackgroundItem ();
        background_item.apps_appeared.connect (add_item);

        icon_groups = new GLib.GenericArray<WorkspaceIconGroup> ();

#if WORKSPACE_SWITCHER
        dynamic_workspace_item = new DynamicWorkspaceIcon ();

        separator = new Gtk.Separator (VERTICAL);
        settings.bind ("icon-size", separator, "height-request", GET);
        put (separator, 0, 0);
#endif

        overflow = VISIBLE;

        resize_animation = new Adw.TimedAnimation (
            this, 0, 0, 0,
            new Adw.CallbackAnimationTarget ((val) => {
                width_request = (int) val;
            })
        );

        resize_animation.done.connect (() => width_request = -1); //Reset otherwise we stay to big when the launcher icon size changes

        settings.changed["icon-size"].connect (reposition_items);

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

            try {
                ItemInterface.get_default ().add_launcher (app_info.get_id ());
            } catch (Error e) {}

            // TODO: What????
            if (AppSystem.get_default ().get_app (app_info.get_id ()) != null) {
                drop_target_file.reject ();
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

    private void reposition_items () {
        int index = 0;
        foreach (var launcher in launchers) {
            position_item (launcher, ref index);
        }

        if (background_item.has_apps) {
            position_item (background_item, ref index);
        }

#if WORKSPACE_SWITCHER
        var separator_y = (get_launcher_size () - separator.height_request) / 2;
        move (separator, index * get_launcher_size () - 1, separator_y);
#endif

        foreach (var icon_group in icon_groups) {
            position_item (icon_group, ref index);
        }

#if WORKSPACE_SWITCHER
        position_item (dynamic_workspace_item, ref index);
#endif
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
        } else if (item is WorkspaceIconGroup) {
            icon_groups.add ((WorkspaceIconGroup) item);
        }

        ulong reveal_cb = 0;
        reveal_cb = resize_animation.done.connect (() => {
            resize_animation.disconnect (reveal_cb);
            reposition_items ();
            item.set_revealed (true);
        });

        resize_animation.easing = EASE_OUT_BACK;
        resize_animation.duration = Granite.TRANSITION_DURATION_OPEN;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length * get_launcher_size ();
        resize_animation.play ();
    }

    private void remove_item (BaseItem item) {
        if (item is Launcher) {
            launchers.remove ((Launcher) item);
        } else if (item is WorkspaceIconGroup) {
            icon_groups.remove ((WorkspaceIconGroup) item);
        }

        item.removed.disconnect (remove_item);
        item.revealed_done.connect (remove_finish);
        item.set_revealed (false);
    }

    private void remove_finish (BaseItem item) {
        // Temporarily set the width request to avoid flicker until the animation calls the callback for the first time
        width_request = get_width ();

        remove (item);
        reposition_items ();

        resize_animation.easing = EASE_IN_OUT_QUAD;
        resize_animation.duration = Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length * get_launcher_size ();
        resize_animation.play ();

        item.revealed_done.disconnect (remove_finish);
        item.cleanup ();
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        unowned GLib.GenericArray<BaseItem>? list = null;
        double offset = 0;
        if (source is Launcher) {
            list = launchers;
        } else if (source is WorkspaceIconGroup) {
            list = icon_groups;
            offset = (launchers.length + (background_item.has_apps ? 1 : 0)) * get_launcher_size (); // +1 for the background item
        } else {
            warning ("Tried to move neither launcher nor icon group");
            return;
        }

        if (target_index >= list.length) {
            target_index = list.length - 1;
        }

        uint source_index = 0;
        list.find (source, out source_index);

        source.animate_move ((get_launcher_size () * target_index) + offset);

        bool right = source_index > target_index;

        // Move the launchers located between the source and the target with an animation
        for (int i = (right ? target_index : (int) (source_index + 1)); i <= (right ? ((int) source_index) - 1 : target_index); i++) {
            list.get (i).animate_move ((right ? (i + 1) * get_launcher_size () : (i - 1) * get_launcher_size ()) + offset);
        }

        list.remove (source);
        list.insert (target_index, source);
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
            return (int) icon_groups.length;
        }

        warning ("Tried to get index of neither launcher nor icon group");
        return 0;
    }

    public void launch (uint index) {
        if (index < 1 || index > launchers.length) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        launchers.get ((int) index - 1).app.launch (context);
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }
}
