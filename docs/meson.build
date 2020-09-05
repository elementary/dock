help2man = find_program('help2man', required: false)
if help2man.found()
	plank_1 = custom_target('plank manpage',
		depends: plank_bin,
		input: 'plank.h2m',
		output: 'plank.1',
		command: [
			help2man, '--no-info', '--include=@INPUT@', '--output=@OUTPUT@', plank_bin.full_path()
		],
		build_by_default: true,
	)
endif

install_man('plank.1')

enable_docs = get_option('enable-docs')
valadoc = find_program('valadoc', required: enable_docs)

if enable_docs
    basic_command = [
        valadoc,
        '--force',
        '--verbose',
        '--package-name',meson.project_name(),
        '--package-version', meson.project_version(),
        '--driver', meson.get_compiler('vala').version(),
        '--pkg', 'gio-unix-2.0',
        '--pkg', 'gmodule-2.0',
        '--pkg', 'granite',
        '--pkg', 'gtk+-3.0',
        '--pkg', 'gdk-x11-3.0',
        '--pkg', 'gdk-pixbuf-2.0',
        '--pkg', 'cairo',
        '--pkg', 'gee-0.8',
        '--pkg', 'libbamf3',
        '--pkg', 'libwnck-3.0',
        '--pkg', 'posix',
        '--pkg', 'x11',
        '--pkg', 'plank-internal',
        '--pkg', 'compat',
        '--pkg', 'config',
        '--vapidir=@0@'.format(join_paths(meson.build_root(), 'lib')),
        '--vapidir=@0@'.format(join_paths(meson.source_root(), 'vapi'))
    ]

    c_doc_target = custom_target(
        'C Documentation',
        command: [
            basic_command,
            '-o', '@OUTPUT@',
            '-X', '-l', '-X', join_paths(meson.build_root(), 'lib', '.libs', 'libplank.so'),
            '-X', join_paths(meson.build_root(), 'lib', 'plank.h'),
            '--doclet=gtkdoc',
            '@INPUT@'
        ],
        build_by_default: true,
        input: plank_lib_sources,
        output: 'c-doc',
        depends: plank_lib
    )

    vala_doc_target = custom_target(
        'Vala Documentation',
        command: [
            basic_command,
            '-o', '@OUTPUT@',
            '--doclet=devhelp',
            '@INPUT@'
        ],
        build_by_default: true,
        input: plank_lib_sources,
        output: 'vala-doc',
        depends: plank_lib
    )

    meson.add_install_script('install_docs.sh')

    web_doc_target = custom_target(
        'Web Documentation',
        command: [
            basic_command,
            '-o', '@OUTPUT@',
            '--doclet=html',
            '@INPUT@'
        ],
        build_by_default: true,
        input: plank_lib_sources,
        output: 'web-doc',
        depends: plank_lib
    )
endif

