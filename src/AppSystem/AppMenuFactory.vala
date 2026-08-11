/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

namespace Dock.AppMenuFactory {
    private const string ACTION_GROUP_PREFIX = "launcher";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string PINNED_ACTION = "pinned";

    public Gtk.Popover create_app_menu (App app) {
        var shell_section = new Menu ();
        shell_section.append (_("Keep in Dock"), ACTION_PREFIX + PINNED_ACTION);

        if (Environment.find_program_in_path ("io.elementary.appcenter") != null) {
            shell_section.append (_("Uninstall"), App.ACTION_PREFIX + App.UNINSTALL_ACTION);
            shell_section.append (_("View in AppCenter"), App.ACTION_PREFIX + App.VIEW_ACTION);
        }

        var menu = new Menu ();
        menu.append_section (null, app.app_action_menu);
        menu.append_section (null, shell_section);

        var popover = new Gtk.PopoverMenu.from_model (menu);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (new PropertyAction (PINNED_ACTION, app, "pinned"));
        popover.insert_action_group (ACTION_GROUP_PREFIX, action_group);

        popover.insert_action_group (App.ACTION_GROUP_PREFIX, app.app_action_group);

        return popover;
    }
}
