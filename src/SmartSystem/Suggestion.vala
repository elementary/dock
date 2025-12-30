/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.Suggestion : Object {
    public string app_id { get; construct; }
    public GenericArray<DateTime> timestamps { get; construct; }

    public Suggestion (string app_id, GenericArray<DateTime> timestamps) {
        Object (app_id: app_id, timestamps: timestamps);
    }

    public DateTime get_last_used () {
        if (timestamps.length == 0) {
            return new DateTime.from_unix_utc (0);
        }

        return timestamps[0];
    }

    public int get_usage_count_in_last_week () {
        return filter_in_span (timestamps, TimeSpan.DAY * 7).length;
    }

    public int get_usage_count_at_current_time_in_last_week (int radius_minutes = 30) {
        var filtered_in_span = filter_in_span (timestamps, TimeSpan.DAY * 7);

        var now = new DateTime.now_utc ();
        var target_minute = now.get_hour () * 60 + now.get_minute ();
        return filter_time (filtered_in_span, target_minute, radius_minutes).length;
    }

    private static GenericArray<DateTime> filter_in_span (GenericArray<DateTime> timestamps, TimeSpan span) {
        var now = new DateTime.now_utc ();
        var filtered = new GenericArray<DateTime> ();

        foreach (var timestamp in timestamps) {
            if (now.difference (timestamp) <= span) {
                filtered.add (timestamp);
            }
        }

        return filtered;
    }

    private static GenericArray<DateTime> filter_time (GenericArray<DateTime> timestamps, int target_minute, int radius) {
        var filtered = new GenericArray<DateTime> ();

        foreach (var timestamp in timestamps) {
            var minute_of_day = timestamp.get_hour () * 60 + timestamp.get_minute ();

            if ((minute_of_day - target_minute).abs () <= radius) {
                filtered.add (timestamp);
            }
        }

        return filtered;
    }

    public static int compare_by_last_used (Suggestion a, Suggestion b) {
        return a.get_last_used ().compare (b.get_last_used ());
    }

    public static int compare_by_usage_count_in_last_week (Suggestion a, Suggestion b) {
        return a.get_usage_count_in_last_week () - b.get_usage_count_in_last_week ();
    }

    public static int compare_by_usage_count_at_current_time_in_last_week (Suggestion a, Suggestion b) {
        return a.get_usage_count_at_current_time_in_last_week () - b.get_usage_count_at_current_time_in_last_week ();
    }
}
