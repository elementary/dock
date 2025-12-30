/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Dock.SmartGroup : Granite.Bin {
    public SmartSystem smart_system { private get; construct; }

    private static Settings settings;

    private Gtk.Revealer revealer;

    public SmartGroup (SmartSystem smart_system) {
        Object (smart_system: smart_system);
    }

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        var flow_box = new Gtk.FlowBox () {
            min_children_per_line = SmartSystem.N_SUGGESTIONS,
            selection_mode = NONE,
            overflow = VISIBLE,
        };
        flow_box.bind_model (smart_system.suggestions, (obj) => new Launcher ((App) obj));
        settings.bind_with_mapping ("icon-size", flow_box, "width-request", GET, (val, variant, user_data) => {
            val.set_int ((variant.get_int32 () + 2 * Launcher.PADDING) * SmartSystem.N_SUGGESTIONS);
            return true;
        }, () => false, null, null);

        var smart_separator = new Gtk.Separator (VERTICAL) {
            valign = START,
            margin_top = Launcher.PADDING,
        };
        settings.bind ("icon-size", smart_separator, "height-request", GET);

        var box = new Granite.Box (HORIZONTAL, NONE) {
            overflow = VISIBLE,
        };
        box.append (flow_box);
        box.append (smart_separator);

        revealer = new Gtk.Revealer () {
            transition_type = SLIDE_LEFT,
            child = box,
            overflow = VISIBLE,
        };
        smart_system.suggestions.bind_property ("n-items", revealer, "reveal-child", SYNC_CREATE);

        child = revealer;
        overflow = VISIBLE;
    }
}
