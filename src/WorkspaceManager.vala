/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

 public class Dock.WorkspaceManager : Gtk.Box {
    private static Settings settings;

    private static GLib.Once<WorkspaceManager> instance;
    public static unowned WorkspaceManager get_default () {
        return instance.once (() => { return new WorkspaceManager (); });
    }

    private DynamicWorkspaceIcon dynamic_workspace_item;

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        dynamic_workspace_item = new DynamicWorkspaceIcon ();

        append (new ItemGroup (WorkspaceSystem.get_default ().workspaces, (obj) => new WorkspaceIconGroup ((Workspace) obj)));
        append (dynamic_workspace_item);

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
        });

        map.connect (() => {
            WorkspaceSystem.get_default ().load.begin ();
        });
    }

    public void move_launcher_after (BaseItem source, int target_index) {
        if (source is WorkspaceIconGroup) {
            WorkspaceSystem.get_default ().reorder_workspace (source.workspace, target_index);
        } else {
            info ("Tried to move not an icon group");
            return;
        }
    }
}
