/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.AppStore : Object {
    private ListStore _apps;
    public ListModel apps { get { return _apps; } }

    construct {
        _apps = new ListStore (typeof (App));

        load.begin ();
    }

    private async void load () {
        var app_system = AppSystem.get_default ();
        var infos = AppInfo.get_all ();
        var known_apps = new GenericSet<App> (null, null);

        foreach (var info in infos) {
            var app = app_system.get_app_by_id (info.get_id ());

            if (app == null || app in known_apps) {
                continue;
            }

            if (!app.app_info.should_show ()) {
                continue;
            }

            _apps.append (app);
            known_apps.add (app);
        }
    }
}
