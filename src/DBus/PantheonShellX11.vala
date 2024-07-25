/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.gala.PantheonShellX11")]
public interface Dock.PantheonShellX11 : GLib.Object { 
    public abstract void set_anchor (string id, Pantheon.Desktop.Anchor anchor) throws GLib.Error;
    public abstract void set_size (string id, int width, int height) throws GLib.Error;
    public abstract void set_hide_mode (string id, Pantheon.Desktop.HideMode hide_mode) throws GLib.Error;
    public abstract void make_centered (string id) throws GLib.Error;
}
