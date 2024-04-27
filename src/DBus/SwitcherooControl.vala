/*
 * SPDX-License-Identifier: GPL-3.0+
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 *                         2020-2021 Justin Haygood
 *                         2020 Bastien Nocera
 */

[DBus (name = "net.hadess.SwitcherooControl")]
public interface SwitcherooControlDBus : Object {
    [DBus (name = "HasDualGpu")]
    public abstract bool has_dual_gpu { owned get; }

    [DBus (name = "GPUs")]
    public abstract HashTable<string,Variant>[] gpus { owned get; }
}

public class Dock.SwitcherooControl : Object {

    private static SwitcherooControlDBus dbus { private set; private get; }

    static construct {
        try {
            dbus = Bus.get_proxy_sync (BusType.SYSTEM,
                "net.hadess.SwitcherooControl", "/net/hadess/SwitcherooControl");
        } catch (IOError e) {
            critical (e.message);
        }
    }

    public bool has_dual_gpu {
        get {
            return dbus.has_dual_gpu;
        }
    }

    public void apply_gpu_environment (AppLaunchContext context, bool use_default_gpu) {
        if (dbus == null) {
            warning ("Could not apply discrete GPU environment, switcheroo-control not available");
            return;
        }
        if (!has_dual_gpu) {
            return;
        }

        foreach (HashTable<string,Variant> gpu in dbus.gpus) {
            bool is_default = gpu.get ("Default").get_boolean ();

            if (is_default == use_default_gpu) {

                debug ("Using GPU: %s", gpu.get ("Name").get_string ());

                var environment = gpu.get ("Environment");

                var environment_set = environment.get_strv ();

                for (int i = 0; environment_set[i] != null; i = i + 2) {
                    context.setenv (environment_set[i], environment_set[i + 1] );
                }

                return;
            }
        }

        warning ("Could not apply discrete GPU environment, no GPUs in list");
    }

    public string get_gpu_name (bool default_gpu) {
        if (dbus == null) {
            warning ("Could not fetch GPU name, switcheroo-control not available");
            return _("Default");
        }

        foreach (HashTable<string,Variant> gpu in dbus.gpus) {
            bool is_default = gpu.get ("Default").get_boolean ();

            if (is_default == default_gpu) {

                string gpu_name = gpu.get ("Name").get_string ();

                debug ("Using GPU: %s", gpu_name);

                if (gpu_name.contains ("NVIDIA")) {
                    return "NVIDIA";
                }

                if (gpu_name.contains ("Intel")) {
                    return "Intel";
                }

                if (gpu_name.contains ("AMD")) {
                    return "AMD";
                }

                return gpu_name;
            }
        }

        return _("Default");
    }
}
