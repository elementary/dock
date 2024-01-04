[DBus (name = "io.elementary.dock.client")]
public class Dock.Client : Object {
    public void add_launcher (string app_id) throws DBusError, IOError {
        LauncherManager.get_default ().add_new_launcher (app_id);
    }

    public void remove_launcher (string app_id) throws DBusError, IOError {
        LauncherManager.get_default ().remove_launcher_by_id (app_id);
    }

    public string[] list_launchers () throws DBusError, IOError {
        return LauncherManager.get_default ().list_launchers ();
    }
}