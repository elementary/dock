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

dep_systemd = dependency('systemd', required: true)
systemd_userunitdir = get_option('systemduserunitdir')
if systemd_userunitdir == ''
    systemd_userunitdir = dep_systemd.get_variable('systemduserunitdir', pkgconfig_define: ['prefix', get_option('prefix')])
endif

bindir = get_option('prefix') / get_option('bindir')
unit_conf = configuration_data()
unit_conf.set('bindir', bindir)

configure_file(
    input: 'dock.service.in',
    output: meson.project_name() + '.service',
    install: true,
    install_dir: systemd_userunitdir,
    configuration: unit_conf
)

install_data(
    'dock.target',
    rename: meson.project_name() + '.target',
    install_dir: systemd_userunitdir
)
