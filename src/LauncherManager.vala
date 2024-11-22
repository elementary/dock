/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

 public class Dock.LauncherManager : Gtk.Fixed {
    private static Settings settings;

    private static GLib.Once<LauncherManager> instance;
    public static unowned LauncherManager get_default () {
        return instance.once (() => { return new LauncherManager (); });
    }

    public Launcher? added_launcher { get; set; default = null; }

    private Adw.TimedAnimation resize_animation;
    private List<Launcher> launchers; //Only used to keep track of launcher indices

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        launchers = new List<Launcher> ();

        overflow = VISIBLE;

        resize_animation = new Adw.TimedAnimation (
            this, 0, 0, 0,
            new Adw.CallbackAnimationTarget ((val) => {
                width_request = (int) val;
            })
        );

        resize_animation.done.connect (() => width_request = -1); //Reset otherwise we stay to big when the launcher icon size changes

        settings.changed.connect ((key) => {
            if (key == "icon-size") {
                reposition_launchers ();
            }
        });

        var drop_target_file = new Gtk.DropTarget (typeof (File), COPY) {
            preload = true
        };
        add_controller (drop_target_file);

        double drop_x, drop_y;
        drop_target_file.enter.connect ((x, y) => {
            drop_x = x;
            drop_y = y;
            return COPY;
        });

        drop_target_file.notify["value"].connect (() => {
            if (drop_target_file.get_value () == null) {
                return;
            }

            if (drop_target_file.get_value ().get_object () == null) {
                return;
            }

            if (!(drop_target_file.get_value ().get_object () is File)) {
                return;
            }

            var file = (File) drop_target_file.get_value ().get_object ();
            var app_info = new DesktopAppInfo.from_filename (file.get_path ());

            if (app_info == null) {
                return;
            }

            //  if (app_info.get_id () in id_to_app) {
            //      id_to_app[app_info.get_id ()].pinned = true;
            //      drop_target_file.reject ();
            //      return;
            //  }

            var position = (int) Math.round (drop_x / get_launcher_size ());
            //  added_launcher = add_launcher (new DesktopAppInfo.from_filename (file.get_path ()), true, true, position);
            added_launcher.moving = true;
        });

        drop_target_file.leave.connect (() => {
            if (added_launcher != null) {
                //Without idle it crashes when the cursor is above the launcher
                Idle.add (() => {
                    remove_launcher (added_launcher);
                    added_launcher = null;
                    return Source.REMOVE;
                });
            }
        });

        AppSystem.get_default ().app_added.connect ((app) => add_launcher (app, true));

        map.connect (AppSystem.get_default ().load);
    }

    private void reposition_launchers () {
        var launcher_size = get_launcher_size ();

        int index = 0;
        foreach (var launcher in launchers) {
            var position = index * launcher_size;

            if (launcher.parent != this) {
                put (launcher, position, 0);
                launcher.current_pos = position;
            } else {
                launcher.animate_move (position);
            }

            index++;
        }
    }

    public static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }

    private Launcher add_launcher (App app, bool reposition = true, int index = -1) {
        var launcher = new Launcher (app);

        app.removed.connect (() => remove_launcher (launcher, true));

        if (index >= 0) {
            launchers.insert (launcher, index);
        } else {
            launchers.append (launcher);
        }

        if (reposition) {
            resize_animation.easing = EASE_OUT_BACK;
            resize_animation.duration = Granite.TRANSITION_DURATION_OPEN;
            resize_animation.value_from = get_width ();
            resize_animation.value_to = launchers.length () * get_launcher_size ();
            resize_animation.play ();

            ulong reveal_cb = 0;
            reveal_cb = resize_animation.done.connect (() => {
                reposition_launchers ();
                launcher.set_revealed (true);
                resize_animation.disconnect (reveal_cb);
            });
        }

        return launcher;
    }

    public void remove_launcher (Launcher launcher, bool animate = true) {
        launchers.remove (launcher);

        if (animate) {
            launcher.set_revealed (false);
            launcher.revealed_done.connect (remove_finish);
        } else {
            remove_finish (launcher);
        }
    }

    private void remove_finish (Launcher launcher) {
        width_request = get_width (); //Temporarily set the width request to avoid flicker until the animation calls the callback for the first time

        remove (launcher);
        reposition_launchers ();

        resize_animation.easing = EASE_IN_OUT_QUAD;
        resize_animation.duration = Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.value_from = get_width ();
        resize_animation.value_to = launchers.length () * get_launcher_size ();
        resize_animation.play ();

        launcher.cleanup ();
    }

    public void move_launcher_after (Launcher source, int target_index) {
        int source_index = launchers.index (source);

        source.animate_move (get_launcher_size () * target_index);

        bool right = source_index > target_index;

        // Move the launchers located between the source and the target with an animation
        for (int i = (right ? target_index : (source_index + 1)); i <= (right ? source_index - 1 : target_index); i++) {
            launchers.nth_data (i).animate_move (right ? (i + 1) * get_launcher_size () : (i - 1) * get_launcher_size ());
        }

        launchers.remove (source);
        launchers.insert (source, target_index);

        sync_pinned ();
    }

    public int get_index_for_launcher (Launcher launcher) {
        return launchers.index (launcher);
    }

    public void sync_pinned () {
        string[] new_pinned_ids = {};

        foreach (var launcher in launchers) {
            if (launcher.app.pinned) {
                new_pinned_ids += launcher.app.app_info.get_id ();
            }
        }

        settings.set_strv ("launchers", new_pinned_ids);
    }

    public void launch (uint index) {
        if (index < 1 || index > launchers.length ()) {
            return;
        }

        var context = Gdk.Display.get_default ().get_app_launch_context ();
        launchers.nth (index - 1).data.app.launch (context);
    }
}
