gresource = gnome.compile_resources(
    'dock-resources',
    'dock.gresource.xml',
    source_dir: meson.current_source_dir()
)

install_data(
    'dock.gschema.xml',
    install_dir: get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas',
    rename: meson.project_name() + '.gschema.xml'
)

i18n.merge_file(
    input: 'dock.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('prefix') / get_option('datadir') / 'metainfo'
)
