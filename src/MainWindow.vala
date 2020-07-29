/*
 * Copyright 2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Dock.MainWindow : Gtk.Window {
    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            decorated: false,
            resizable: false,
            skip_pager_hint: true,
            skip_taskbar_hint: true,
            title: "Dock",
            type_hint: Gdk.WindowTypeHint.DOCK
        );
    }

    construct {
        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/dock/Application.css");
        Gtk.StyleContext.add_provider_for_screen (get_screen (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var app_icon = new Gtk.Image.from_icon_name (
            "preferences-desktop",
            Gtk.IconSize.DIALOG
        );

        var grid = new Gtk.Grid ();
        grid.add (app_icon);

        add (grid);
    }
}
