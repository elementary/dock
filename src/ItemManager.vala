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
    private Gtk.Revealer workspaces_scrollbar_revealer;
#endif

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        var app_group = new ItemGroup (AppSystem.get_default ().apps, (obj) => new Launcher ((App) obj));

        var app_group_scrolled = new Gtk.ScrolledWindow () {
            child = app_group,
            vscrollbar_policy = NEVER,
            propagate_natural_width = true
        };

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

        var workspace_group_scrolled = new Gtk.ScrolledWindow () {
            child = new ItemGroup (WorkspaceSystem.get_default ().workspaces, (obj) => new WorkspaceIconGroup ((Workspace) obj)),
            hscrollbar_policy = EXTERNAL,
            vscrollbar_policy = NEVER,
            propagate_natural_width = true
        };

        /*
         * Gtk.ScrolledWindow with scrollbar policy set to ALWAYS or AUTOMATIC reserves ~30px of space for scrollbar
         * And it doesn't matter if the scrollbar is shown or not, the space is always reserved.
         * Essentially, by default workspace_group_scrolled's minimum size is 30px, to avoid this
         * we set scrollbar policy to EXTERNAL and handle scrollbar ourselves.
         */

        var workspaces_scrollbar = new Gtk.Scrollbar (HORIZONTAL, workspace_group_scrolled.hadjustment) {
            vexpand = false,
            valign = END
        };

        workspaces_scrollbar_revealer = new Gtk.Revealer () {
            child = workspaces_scrollbar,
            vexpand = false,
            valign = END
        };

        update_workspaces_scrollbar_revealer (workspace_group_scrolled.hadjustment);
        workspace_group_scrolled.hadjustment.changed.connect (update_workspaces_scrollbar_revealer);

        var scrollbar_overlay = new Gtk.Overlay () {
            child = workspace_group_scrolled
        };
        scrollbar_overlay.add_overlay (workspaces_scrollbar_revealer);

        dynamic_workspace_item = new DynamicWorkspaceIcon ();
#endif

        append (app_group_scrolled);
        append (background_group);
#if WORKSPACE_SWITCHER
        append (separator_box);
        append (scrollbar_overlay);
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

    private void update_workspaces_scrollbar_revealer (Gtk.Adjustment adjustment) {
        workspaces_scrollbar_revealer.reveal_child = adjustment.upper - adjustment.lower > adjustment.page_size;
    }
}
