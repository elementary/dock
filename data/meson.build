gnome = import('gnome')
gresource = gnome.compile_resources(
    'dock-resources',
    'dock.gresource.xml',
    source_dir: join_paths(meson.source_root(), 'data')
)

install_data(
    'dock.gschema.xml',
    install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
    rename: meson.project_name() + '.gschema.xml'
)

install_data(
    'dock.desktop',
    install_dir: get_option('sysconfdir') / 'xdg' / 'autostart'
)
