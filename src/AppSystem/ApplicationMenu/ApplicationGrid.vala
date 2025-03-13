/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Dock.ApplicationGrid : Granite.Bin {
    private AppCache app_cache;
    private Adw.Carousel carousel;

    construct {
        app_cache = new AppCache ();

        carousel = new Adw.Carousel () {
            hexpand = true,
            vexpand = true
        };

        var dots = new Adw.CarouselIndicatorDots () {
            carousel = carousel
        };

        var box = new Gtk.Box (VERTICAL, 6) {
            margin_bottom = 12,
            margin_top = 12,
            margin_start = 12,
            margin_end = 12
        };
        box.append (carousel);
        box.append (dots);

        child = box;
        height_request = ApplicationMenu.HEIGHT;
        width_request = ApplicationMenu.WIDTH;

        repopulate_carousel ();
        app_cache.apps.items_changed.connect (repopulate_carousel);
    }

    private void repopulate_carousel () {
        var n_pages = app_cache.apps.n_items / ApplicationGridPage.PAGE_SIZE;
        for (int i = 0; i < n_pages; i++) {
            if (i < carousel.n_pages) {
                continue;
            }

            var page = new ApplicationGridPage (app_cache.apps, i);
            carousel.append (page);
        }

        //  for (uint i = carousel.n_pages - 1; i >= n_pages; i--) {
        //      carousel.remove (carousel.get_nth_page (i));
        //  }
    }
}
