// TODO: Copyright

public class Dock.Workspace : GLib.Object {
    public signal void removed ();
    public signal void windows_changed ();

    public int index { get; construct; }
    public Gee.List<WorkspaceWindow> windows { get; private owned set; }

    public Workspace (int index) {
        Object (index: index);
    }

    construct {
        windows = new Gee.LinkedList<WorkspaceWindow> ();
    }

    public WorkspaceWindow? find_window (uint64 window_uid) {
        var found_win = windows.first_match ((win) => {
            return win.uid == window_uid;
        });

        if (found_win != null) {
            return found_win;
        } else {
            return null;
        }
    }

    public void update_windows (Gee.List<WorkspaceWindow>? new_windows) {
        if (new_windows == null) {
            windows = new Gee.LinkedList<WorkspaceWindow> ();
        } else {
            windows = new_windows;
        }

        if (windows.size == 0) {
            removed ();
        } else {
            windows_changed ();
        }
    }

    public void activate () {
        AppSystem.get_default ().desktop_integration.activate_workspace.begin (index);
    }
}
