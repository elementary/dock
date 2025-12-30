/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.SmartSystem : Object {
    public const int N_SUGGESTIONS = 6;

    private static Settings settings;

    public AppSystem app_system { private get; construct; }

    private ListStore suggestions_store;
    public ListModel suggestions { get { return suggestions_store; } }

    private Database database;

    public SmartSystem (AppSystem app_system) {
        Object (app_system: app_system);
    }

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        suggestions_store = new ListStore (typeof (App));

        database = new Database ();

        Timeout.add_seconds (5, () => {
            collect_focus_window.begin ();
            return Source.CONTINUE;
        });

        update_suggestions ();
        Timeout.add_seconds (30, () => {
            update_suggestions ();
            return Source.CONTINUE;
        });

        settings.changed["smart-suggestions"].connect (update_suggestions);
    }

    private void update_suggestions () {
        if (!settings.get_boolean ("smart-suggestions")) {
            suggestions_store.remove_all ();
            return;
        }

        var pinned_apps = new GenericSet<string> (str_hash, str_equal);

        foreach (var app in settings.get_strv ("launchers")) {
            pinned_apps.add (app);
        }

        var apps = database.get_apps ();
        var new_suggestions = new GenericArray<Suggestion> ();

        foreach (var app_id in apps) {
            if (app_id in pinned_apps) {
                continue;
            }

            var timestamps = database.get_app_usage_timestamps (app_id);
            new_suggestions.add (new Suggestion (app_id, timestamps));
        }

        if (new_suggestions.length < N_SUGGESTIONS) {
            suggestions_store.remove_all ();
            return;
        }

        var suggested_apps = new App[N_SUGGESTIONS];

        suggested_apps[0] = get_highest (new_suggestions, Suggestion.compare_by_last_used);
        suggested_apps[1] = get_highest (new_suggestions, Suggestion.compare_by_last_used);
        suggested_apps[2] = get_highest (new_suggestions, Suggestion.compare_by_usage_count_in_last_week);
        suggested_apps[3] = get_highest (new_suggestions, Suggestion.compare_by_usage_count_in_last_week);
        suggested_apps[4] = get_highest (new_suggestions, Suggestion.compare_by_usage_count_at_current_time_in_last_week);
        suggested_apps[5] = get_highest (new_suggestions, Suggestion.compare_by_usage_count_at_current_time_in_last_week);

        suggestions_store.splice (0, suggestions_store.get_n_items (), suggested_apps);
    }

    private App get_highest (
        GenericArray<Suggestion> suggestions, CompareFunc<Suggestion> compare
    ) requires (suggestions.length > 0) {
        Suggestion? highest = null;

        foreach (var suggestion in suggestions) {
            if (highest == null || compare (suggestion, highest) > 0) {
                highest = suggestion;
            }
        }

        suggestions.remove (highest);

        return app_system.get_app_by_id (highest.app_id);
    }

    private async void collect_focus_window () {
        if (!settings.get_boolean ("smart-suggestions")) {
            return;
        }

        var window_system = WindowSystem.get_default ();

        yield window_system.sync_windows ();

        foreach (var window in window_system.windows) {
            if (window.has_focus) {
                database.add_app_usage_timestamp (window.app_id, new DateTime.now_utc ());
                break;
            }
        }
    }
}
