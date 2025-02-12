// TODO: Copyright

public class Dock.Workspace : GLib.Object {
    public DesktopIntegration.Workspace di_workspace { get; construct set; }

    public signal void removed ();

    public Workspace (DesktopIntegration.Workspace di_workspace) {
        Object (di_workspace: di_workspace);
    }

    public void update (DesktopIntegration.Workspace new_di_workspace) {
        di_workspace = new_di_workspace;
    }

    public void remove () {
        removed ();
    }
}
