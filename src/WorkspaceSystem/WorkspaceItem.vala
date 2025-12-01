/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Dock.WorkspaceItem : Object {
    public abstract int workspace_index { get; }

    public abstract void window_entered (Window window);
    public abstract void window_left ();
}
