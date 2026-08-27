/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

 /**
 * Custom Granite.Bin subclass that implements common animation properties
 * for ease of use with Adw.PropertyAnimationTarget.
 */
public class Dock.AnimatableWidget : Granite.Bin {
    private double _translation_x = 0.0;
    public double translation_x {
        private get { return _translation_x; }
        set {
            _translation_x = value;
            update_allocation ();

        }
    }

    private double _translation_y = 0.0;
    public double translation_y {
        private get { return _translation_y; }
        set {
            _translation_y = value;
            update_allocation ();
        }
    }

    private double _scale = 1.0;
    public double scale {
        private get { return _scale; }
        set {
            _scale = value;
            update_allocation ();
        }
    }

    private void update_allocation () {
        var width = get_width ();
        var height = get_height ();

        var center_x = (width - (scale * width)) / 2.0;
        var center_y = (height - (scale * height)) / 2.0;

        allocate (
            width, height, -1,
            new Gsk.Transform ()
                .scale ((float) scale, (float) scale)
                .translate (Graphene.Point ().init (
                    (int) (center_x + translation_x),
                    (int) (center_y + translation_y)
                ))
        );
    }
}
