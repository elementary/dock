/*
 * TODO: Copyright
 */

// TODO: Maybe combine this with AppWindow?
public class Dock.WorkspaceWindow : GLib.Object {
    private static GLib.ThemedIcon default_icon = new GLib.ThemedIcon ("application-default-icon");

    public uint64 uid { get; construct set; }

    public GLib.Icon icon { get; private set; default = default_icon; }

    public WorkspaceWindow (uint64 uid) {
        Object (uid: uid);
    }

    public void update_properties (GLib.HashTable<string, Variant> properties) {
        if (!("app-id" in properties)) {
            return;
        }

        unowned var app_id = properties["app-id"].get_string ();
        if (app_id != null) {
            var app_info = new GLib.DesktopAppInfo (app_id);
            if (app_info != null) {
                var icon = app_info.get_icon ();
                if (icon != null && Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_gicon (icon)) {
                    this.icon = icon;
                }
            }
        }
    }
}
