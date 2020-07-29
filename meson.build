project(
    'io.elementary.dock',
    'vala', 'c',
    version: '0.0.0'
)

gnome = import('gnome')

asresources = gnome.compile_resources(
    'as-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/MainWindow.vala',
    asresources,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite', version: '>= 5.4.0'),
        dependency('gtk+-3.0'),
    ],
    install : true
)
