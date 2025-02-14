/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

 public class Dock.ItemManager : Gtk.Fixed {
    private static GLib.Once<ItemManager> instance;
    public static unowned ItemManager get_default () {
        return instance.once (() => { return new ItemManager (); });
    }

    public Launcher? added_launcher { get; set; default = null; }

    private Adw.TimedAnimation resize_animation;
    private List<Launcher> launchers; // Only used to keep track of launcher indices
    private List<IconGroup> icon_groups; // Only used to keep track of icon group indices
    private DynamicWorkspaceIcon? dynamic_workspace_item;

    construct {
        launchers = new List<Launcher> ();
        icon_groups = new List<IconGroup> ();

        overflow = VISIBLE;

        resize_animation = new Adw.TimedAnimation (
            this, 0, 0, 0,
            new Adw.CallbackAnimationTarget ((val) => {
                width_request = (int) val;
            })
        );

        resize_animation.done.connect (() => width_request = -1); //Reset otherwise we stay to big when the launcher icon size changes

        DockSettings.get_default ().notify["icon-size"].connect (reposition_items);

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

            unowned var app_system = AppSystem.get_default ();

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
        });
    }

    private void reposition_items () {
        var launcher_size = get_launcher_size ();
        var index = 0;

        foreach (var launcher in launchers) {
            var position = index * launcher_size;

            if (launcher.parent != this) {
                put (launcher, position, 0);
                launcher.current_pos = position;
            } else {
                launcher.animate_move (position);
            }

            index++;
        }

        foreach (var icon_group in icon_groups) {
            var position = index * launcher_size;

            if (icon_group.parent != this) {
                put (icon_group, position, 0);
                icon_group.current_pos = position;
            } else {
                icon_group.animate_move (position);
            }

            index++;
        }

        // this is here to avoid loop where ItemManager creates DynamicWorkspaceIcon that depends on ItemManager
        if (dynamic_workspace_item == null) {
            dynamic_workspace_item = new DynamicWorkspaceIcon ();
        }

        var position = index * launcher_size;
        if (dynamic_workspace_item.parent != this) {
            put (dynamic_workspace_item, position, 0);
            dynamic_workspace_item.current_pos = position;
        } else {
            dynamic_workspace_item.animate_move (position);
        }

        index++;
    }

    private void setup_item_removed (DockItem item) {
        item.removed.connect ((_item) => {
            if (_item is Launcher) {
                launchers.remove ((Launcher) _item);
            } else if (_item is IconGroup) {
                icon_groups.remove ((IconGroup) _item);
            }

            remove_item (_item);
        });
    }

    private void add_launcher_via_dnd (Launcher launcher, int index = -1) {
        setup_item_removed (launcher);

        launchers.insert (launcher, index);
        reposition_items ();
        launcher.set_revealed (true);
    }

    private void add_item (DockItem item) {
        setup_item_removed (item);

        if (item is Launcher) {
            launchers.append ((Launcher) item);
        } else if (item is IconGroup) {
            icon_groups.append ((IconGroup) item);
        }

        resize_animation.easing = EASE_OUT_BACK;
        resize_animation.duration = Granite.TRANSITION_DURATION_OPEN;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length () * get_launcher_size ();
        resize_animation.play ();

        ulong reveal_cb = 0;
        reveal_cb = resize_animation.done.connect (() => {
            reposition_items ();
            item.set_revealed (true);
            resize_animation.disconnect (reveal_cb);
        });
    }

    private void remove_item (DockItem item) {
        item.set_revealed (false);
        item.revealed_done.connect (remove_item_finish);
    }

    private void remove_item_finish (DockItem item) {
        width_request = get_width (); // Temporarily set the width request to avoid flicker until the animation calls the callback for the first time

        remove (item);
        reposition_items ();

        resize_animation.easing = EASE_IN_OUT_QUAD;
        resize_animation.duration = Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length () * get_launcher_size ();
        resize_animation.play ();

        item.cleanup ();
    }

    public void move_launcher_after (Launcher source, int target_index) {
        int source_index = launchers.index (source);

        source.animate_move (get_launcher_size () * target_index);

        bool right = source_index > target_index;

        // Move the launchers located between the source and the target with an animation
        for (int i = (right ? target_index : (source_index + 1)); i <= (right ? source_index - 1 : target_index); i++) {
            launchers.nth_data (i).animate_move (right ? (i + 1) * get_launcher_size () : (i - 1) * get_launcher_size ());
        }

        launchers.remove (source);
        launchers.insert (source, target_index);

        sync_pinned ();
    }

    public int get_index_for_launcher (Launcher launcher) {
        return launchers.index (launcher);
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        foreach (var launcher in launchers) {
            if (launcher.app.pinned) {
                new_pinned_ids += launcher.app.app_info.get_id ();
            }
        }

        DockSettings.get_default ().launchers = new_pinned_ids;
    }

    public void launch (uint index) {
        if (index < 1 || index > launchers.length ()) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        launchers.nth (index - 1).data.app.launch (context);
    }

    public static int get_launcher_size () {
        return DockSettings.get_default ().icon_size + Launcher.PADDING * 2;
    }
}
