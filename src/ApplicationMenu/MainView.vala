/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.MainView : Granite.Bin {
    private const string APP_GRID = "app-grid";
    private const string SEARCH_VIEW = "search-view";

    public Detective.Engine engine { private get; construct; }

    private Gtk.SearchEntry entry;
    private SearchView search_view;
    private Gtk.Stack stack;

    public MainView (Detective.Engine engine) {
        Object (engine: engine);
    }

    construct {
        entry = new Gtk.SearchEntry () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6,
            placeholder_text = _("Search apps, files and more..."),
            search_delay = 0
        };

        var app_carousel = new AppCarousel ();

        search_view = new SearchView (engine);

        stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        stack.add_named (app_carousel, APP_GRID);
        stack.add_named (search_view, SEARCH_VIEW);

        var toolbar_view = new Adw.ToolbarView () {
            content = stack
        };
        toolbar_view.add_top_bar (entry);

        child = toolbar_view;

        map.connect (() => entry.grab_focus ());
        unmap.connect (on_unmap);

        entry.search_changed.connect (on_search_changed);
        entry.activate.connect (on_entry_activated);
        entry.stop_search.connect (close);

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        child.add_controller (key_controller);
    }

    private void on_unmap () {
        engine.clear_search ();
        entry.text = "";
    }

    private void on_search_changed () {
        if (entry.text.strip () != "") {
            engine.search (entry.text);
            stack.visible_child_name = SEARCH_VIEW;
        } else {
            engine.clear_search ();
            stack.visible_child_name = APP_GRID;
        }
    }

    private void on_entry_activated () {
        //  search_view.activate_selected ();
    }

    private bool on_key_pressed (uint keyval, uint keycode) {
        if (keyval == Gdk.Key.Escape) {
            close ();
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private void close () {
        activate_action_variant ("window.close", null);
    }
}
