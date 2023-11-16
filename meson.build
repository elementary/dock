project(
  'io.elementary.dock',
  'vala', 'c',
  version: '1.0.0',
  meson_version: '>=0.57'
)

cc = meson.get_compiler('c')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gtk_dep = dependency('gtk4')
granite_dep = dependency('granite-7')
m_dep = cc.find_library('m')

dependencies = [
    gio_dep,
    gio_unix_dep,
    glib_dep,
    gobject_dep,
    gtk_dep,
    granite_dep,
    m_dep
]

gnome.post_install(glib_compile_schemas: true)

subdir('data')
subdir('src')
