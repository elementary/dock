/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023-2026 elementary, Inc. (https://elementary.io)
 */

 public class Dock.ItemManager : Gtk.Box {
    private static Settings settings;

    public Launcher? added_launcher { get; set; default = null; }

#if WORKSPACE_SWITCHER
    private Gtk.Separator separator;
    private DynamicWorkspaceIcon dynamic_workspace_item;
#endif
    private ListStore all_item_groups;
    private Gtk.FlattenListModel all_items;
    private bool changed_focus = false;

    class construct {
        set_accessible_role (LIST);
    }

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        var app_group = new ItemGroup (AppSystem.get_default ().apps, (obj) => new Launcher ((App) obj));

        var background_item = new BackgroundItem ();
        var background_group = new ItemGroup (background_item.group_model, (obj) => (BackgroundItem) obj);

#if WORKSPACE_SWITCHER
        separator = new Gtk.Separator (VERTICAL) {
            margin_top = Launcher.PADDING
        };
        settings.bind ("icon-size", separator, "height-request", GET);

        var separator_box = new Gtk.Box (VERTICAL, 0);
        separator_box.append (new TopMargin ());
        separator_box.append (separator);

        var workspaces_group = new ItemGroup (WorkspaceSystem.get_default ().workspaces, (obj) => new WorkspaceIconGroup ((Workspace) obj));

        dynamic_workspace_item = new DynamicWorkspaceIcon ();
#endif

        append (app_group);
        append (background_group);
#if WORKSPACE_SWITCHER
        append (separator_box);
        append (workspaces_group);
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
#if WORKSPACE_SWITCHER
            WorkspaceSystem.get_default ().load.begin ();
#endif
        });

        all_item_groups = new GLib.ListStore (typeof (GLib.ListModel));
        all_item_groups.append (app_group.current_children);
        all_item_groups.append (background_group.current_children);
#if WORKSPACE_SWITCHER
        all_item_groups.append (workspaces_group.current_children);

        var dynamic_workspace_item_list = new GLib.ListStore (typeof (DynamicWorkspaceIcon));
        dynamic_workspace_item_list.append (dynamic_workspace_item);

        all_item_groups.append (dynamic_workspace_item_list);
#endif

        all_items = new Gtk.FlattenListModel (all_item_groups);
        all_items.items_changed.connect ((all_items, position, removed, added) => {
            if (!changed_focus) {
                ((BaseItem) all_items.get_item (0)).grab_focus ();
            }
        });

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        add_controller (key_controller);
    }

    private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
        unowned var current_focus = ((Gtk.Window) root).get_focus ();
        if (current_focus == null ||
            !(current_focus.is_ancestor (this))
        ) {
            return false;
        }

        unowned var current_item = current_focus.get_ancestor (typeof (BaseItem));
        if (current_item == null) {
            return false;
        }

        int current_position = -1;
        var n_items = all_items.n_items;
        for (var i = 0; i < n_items; i++) {
            var item = (BaseItem) all_items.get_item (i);
            if (item == current_item) {
                current_position = i;
                break;
            }
        }

        if (current_position == -1) {
            return false;
        }

        BaseItem? next_widget = null;
        switch (keyval) {
            case Gdk.Key.Left:
                if (current_position != 0) {
                    next_widget = (BaseItem) all_items.get_item (current_position - 1);
                }
                break;
            case Gdk.Key.Right:
                if (current_position != all_items.n_items - 1) {
                    next_widget = (BaseItem) all_items.get_item (current_position + 1);
                }
                break;
            default:
                return false;
        }

        if (next_widget != null) {
            next_widget.grab_focus ();
            changed_focus = true;
            queue_draw ();
            return true;
        }

        return false;
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        if (source is Launcher) {
            AppSystem.get_default ().reorder_app (source.app, target_index);
        } else if (source is WorkspaceIconGroup) {
            WorkspaceSystem.get_default ().reorder_workspace (source.workspace, target_index);
        } else {
            warning ("Tried to move neither launcher nor icon group");
        }
    }
}
