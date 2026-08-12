/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

public class Dock.TopMargin : Gtk.Widget {
    public const int SIZE = 64;

    construct {
        height_request = SIZE;
    }
}
