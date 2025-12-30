/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.Database : Object {
    private KeyFile key_file;

    private uint queue_save_id = 0;

    construct {
        key_file = new KeyFile ();
        try {
            key_file.load_from_file (get_database_path (), KeyFileFlags.NONE);
        } catch (FileError.NOENT e) {
            // If the file does not exist yet, we can ignore the error
        } catch (Error e) {
            warning ("Failed to load database file: %s", e.message);
        }
    }

    private string get_database_path () {
        var data_dir = Environment.get_user_data_dir ();
        return Path.build_filename (data_dir, "io.elementary.dock.usage_database");
    }

    public void add_app_usage_timestamp (string app_id, DateTime timestamp) {
        var new_timestamps = new GenericArray<string> ();
        new_timestamps.add (timestamp.format_iso8601 ());

        try {
            var old_timestamps = key_file.get_string_list (app_id, "usage_timestamps");

            foreach (var old_timestamp in old_timestamps) {
                new_timestamps.add (old_timestamp);
            }
        } catch (Error e) {
            // If there are no old timestamps, we can ignore the error
        }

        key_file.set_string_list (app_id, "usage_timestamps", new_timestamps.data);

        queue_save ();
    }

    private void queue_save () {
        if (queue_save_id != 0) {
            return;
        }

        queue_save_id = Timeout.add_seconds_once (60, () => save_file.begin ());
    }

    private async void save_file () {
        var file = File.new_for_path (get_database_path ());

        try {
            yield file.replace_contents_async (key_file.to_data ().data, null, false, NONE, null, null);
        } catch (Error e) {
            warning ("Failed to save database file: %s", e.message);
        }

        queue_save_id = 0;
    }

    public string[] get_apps () {
        return key_file.get_groups ();
    }

    public GenericArray<DateTime> get_app_usage_timestamps (string app_id) {
        var timestamps = new GenericArray<DateTime> ();
        try {
            var string_timestamps = key_file.get_string_list (app_id, "usage_timestamps");

            foreach (var str_timestamp in string_timestamps) {
                timestamps.add (new DateTime.from_iso8601 (str_timestamp, null));
            }
        } catch (Error e) {
            warning ("Failed to get usage timestamps for app '%s': %s", app_id, e.message);
        }

        return timestamps;
    }
}
