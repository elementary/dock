/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.AppCarousel : Granite.Bin {
    private const int PAGE_SIZE = AppCarouselPage.COLUMNS * AppCarouselPage.ROWS;

    private AppStore app_store;

    private Adw.Carousel carousel;

    construct {
        carousel = new Adw.Carousel ();

        var dots = new Adw.CarouselIndicatorDots () {
            carousel = carousel
        };

        var box = new Granite.Box (VERTICAL, NONE);
        box.append (carousel);
        box.append (dots);

        child = box;

        app_store = new AppStore ();
        app_store.apps.items_changed.connect (on_apps_changed);
        on_apps_changed (0, 0, app_store.apps.get_n_items ());
    }

    private void on_apps_changed (uint pos, uint removed, uint added) {
        while (carousel.get_first_child () != null) {
            carousel.remove (carousel.get_first_child ());
        }

        for (uint i = 0; i < app_store.apps.get_n_items (); i += PAGE_SIZE) {
            var slice = new Gtk.SliceListModel (app_store.apps, i, PAGE_SIZE);
            var page = new AppCarouselPage (slice);

            carousel.append (page);
        }
    }

    public override bool focus (Gtk.DirectionType direction) {
        var active_page = carousel.get_nth_page ((int) carousel.position);

        if (active_page.child_focus (direction)) {
            return true;
        }

        Gtk.Widget? next;

        switch (direction) {
            case RIGHT:
            case TAB_FORWARD:
                next = active_page.get_next_sibling ();
                break;

            case LEFT:
            case TAB_BACKWARD:
                next = active_page.get_prev_sibling ();
                break;

            default:
                return false;
        }

        if (next != null) {
            carousel.scroll_to (next, true);
            return next.child_focus (direction);
        }

        return false;
    }
}
