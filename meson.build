project(
  'io.elementary.dock',
  'vala', 'c',
  version: '1.0.0',
  meson_version: '>=0.58'
)

cc = meson.get_compiler('c')
vala = meson.get_compiler('vala')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gtk_dep = dependency('gtk4')
gtk_wayland_dep = dependency('gtk4-wayland')
gtk_x11_dep = dependency('gtk4-x11')
granite_dep = dependency('granite-7')
adw_dep = dependency('libadwaita-1')
m_dep = cc.find_library('m')
wl_client_dep = dependency('wayland-client')

subdir('protocol')

dependencies = [
    gee_dep,
    gio_dep,
    gio_unix_dep,
    glib_dep,
    gobject_dep,
    gtk_dep,
    gtk_wayland_dep,
    gtk_x11_dep,
    granite_dep,
    adw_dep,
    m_dep,
    wl_client_dep,
    pantheon_desktop_shell_dep
]

gnome.post_install(glib_compile_schemas: true)

subdir('data')
subdir('po')
subdir('src')
