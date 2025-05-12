project(
  'io.elementary.dock',
  'vala', 'c',
  version: '8.1.0',
  meson_version: '>=0.58'
)

cc = meson.get_compiler('c')
vala = meson.get_compiler('vala')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

vala_flags = []
if get_option('workspace-switcher')
    vala_flags = ['--define', 'WORKSPACE_SWITCHER']
endif

add_project_arguments(vala_flags, language: 'vala')

glib_version = '2.74'
gio_dep = dependency('gio-2.0', version: '>=@0@'.format(glib_version))
gio_unix_dep = dependency('gio-unix-2.0', version: '>=@0@'.format(glib_version))
glib_dep = dependency('glib-2.0', version: '>=@0@'.format(glib_version))
gobject_dep = dependency('gobject-2.0', version: '>=@0@'.format(glib_version))
gtk_dep = dependency('gtk4')
gtk_wayland_dep = dependency('gtk4-wayland')
gtk_x11_dep = dependency('gtk4-x11')
x11_dep = dependency('x11')
granite_dep = dependency('granite-7')
adw_dep = dependency('libadwaita-1')
m_dep = cc.find_library('m')
wl_client_dep = dependency('wayland-client')

subdir('protocol')

dependencies = [
    gio_dep,
    gio_unix_dep,
    glib_dep,
    gobject_dep,
    gtk_dep,
    gtk_wayland_dep,
    gtk_x11_dep,
    x11_dep,
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
