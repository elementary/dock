/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

/**
 * A widget that shows the app icon along with the unity badge and progress bar
 * if they are requested by the app.
 */
public class Dock.AppWidget : Granite.Bin {
    private static Settings? notify_settings;

    static construct {
        if (SettingsSchemaSource.get_default ().lookup ("io.elementary.notifications", true) != null) {
            notify_settings = new Settings ("io.elementary.notifications");
        }
    }

    public App app { get; construct; }

    public int icon_size { set { image.pixel_size = value; } }

    private Gtk.Image image;
    private Gtk.Label badge;
    private Gtk.Revealer progress_revealer;
    private Adw.TimedAnimation badge_fade;
    private Adw.TimedAnimation badge_scale;

    public AppWidget (App app) {
        Object (app: app);
    }

    construct {
        image = new Gtk.Image ();

        var icon = app.app_info.get_icon ();
        if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
            image.gicon = icon;
        } else {
            image.gicon = new ThemedIcon ("application-default-icon");
        }

        badge = new Gtk.Label ("!");
        badge.add_css_class (Granite.STYLE_CLASS_BADGE);
        app.bind_property ("current_count", badge, "label", SYNC_CREATE,
            (binding, srcval, ref targetval) => {
                var src = (int64) srcval;

                if (src > 0) {
                    targetval.set_string ("%lld".printf (src));
                } else {
                    targetval.set_string ("!");
                }

                return true;
            }, null
        );

        var badge_container = new Granite.Bin () {
            can_target = false,
            child = badge,
            halign = END,
            valign = START,
            overflow = VISIBLE
        };

        progress_revealer = new Gtk.Revealer () {
            can_target = false,
            transition_type = CROSSFADE
        };

        var overlay = new Gtk.Overlay () {
            child = image
        };
        overlay.add_overlay (badge_container);
        overlay.add_overlay (progress_revealer);

        child = overlay;

        // We have to destroy the progressbar when it is not needed otherwise it will
        // cause continuous layouting of the surface see https://github.com/elementary/dock/issues/279
        progress_revealer.notify["child-revealed"].connect (() => {
            if (!progress_revealer.child_revealed) {
                progress_revealer.child = null;
            }
        });

        badge_scale = new Adw.TimedAnimation (
            badge, 0.25, 1,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                var height = badge_container.get_height ();
                var width = badge_container.get_width ();

                var x = (float) (width - (val * width)) / 2;
                var y = (float) (height - (val * height)) / 2;

                badge.allocate (
                    width, height, -1,
                    new Gsk.Transform ().scale ((float) val, (float) val).translate (Graphene.Point ().init (x, y))
                );
            })
        );

        badge_fade = new Adw.TimedAnimation (
            badge, 0, 1,
            Granite.TRANSITION_DURATION_OPEN,
            new Adw.CallbackAnimationTarget ((val) => {
                badge.opacity = val;
            })
        ) {
            easing = EASE_IN_OUT_QUAD
        };

        app.notify["count-visible"].connect (update_badge_revealed);
        update_badge_revealed ();

        if (notify_settings != null) {
            notify_settings.changed["do-not-disturb"].connect (update_badge_revealed);
        }

        app.notify["progress-visible"].connect (update_progress_revealer);
        update_progress_revealer ();
    }

    private void update_badge_revealed () {
        badge_fade.skip ();
        badge_scale.skip ();

        // Avoid a stutter at the beginning
        badge.opacity = 0;

        if (app.count_visible && (notify_settings == null || !notify_settings.get_boolean ("do-not-disturb"))) {
            badge_fade.duration = Granite.TRANSITION_DURATION_OPEN;
            badge_fade.reverse = false;

            badge_scale.duration = Granite.TRANSITION_DURATION_OPEN;
            badge_scale.easing = EASE_OUT_BACK;
            badge_scale.reverse = false;
        } else {
            badge_fade.duration = Granite.TRANSITION_DURATION_CLOSE;
            badge_fade.reverse = true;

            badge_scale.duration = Granite.TRANSITION_DURATION_CLOSE;
            badge_scale.easing = EASE_OUT_QUAD;
            badge_scale.reverse = true;
        }

        badge_fade.play ();
        badge_scale.play ();
    }

    private void update_progress_revealer () {
        progress_revealer.reveal_child = app.progress_visible;

        // See comment above and https://github.com/elementary/dock/issues/279
        if (progress_revealer.reveal_child && progress_revealer.child == null) {
            var progress_bar = new Gtk.ProgressBar () {
                valign = END
            };
            app.bind_property ("progress", progress_bar, "fraction", SYNC_CREATE);

            progress_revealer.child = progress_bar;
        }
    }
}
