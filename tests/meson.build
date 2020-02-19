enable_headless_tests = get_option('enable-headless-tests')
if enable_headless_tests
	xvfb_run = find_program('xvfb-run', required: true)
	dbus_run_session = find_program('dbus-run-session', required: true)
endif

gtester = find_program('gtester', required: true)

tests_bin_sources = [
	'Controller.vala',
	'Drawing.vala',
	'Items.vala',
	'Main.vala',
	'Preferences.vala',
	'TestHelper.vala',
	'Widgets.vala',
]

tests_bin = executable(
	'tests',
	tests_bin_sources,
	'test-config.vapi',
	dependencies: [plank_dep, plank_internal_dep, plank_base_dep, wnck_x11_dep],
	c_args: [
		'-DTEST_DATA_DIR="@0@/tests/data"'.format(meson.source_root()),
		'-DTEST_HOME_DIR="@0@/tests/home"'.format(meson.build_root()),
	],
)

dock_bin_sources = [
	'Dock.vala',
]

dock_bin = executable(
	'dock',
	dock_bin_sources,
	'test-config.vapi',
	plank_gschema_compile,
	dependencies: [plank_dep, plank_base_dep],
)

test_env = [
	'HOME=@0@/tests/home'.format(meson.build_root()),
	'GSETTINGS_SCHEMA_DIR=@0@/data'.format(meson.build_root()),
	'PLANK_DOCKLET_DIRS=@0@/docklets'.format(meson.build_root()),
]

if enable_headless_tests
	add_test_setup(
		'default',
		exe_wrapper: [join_paths(meson.source_root(), 'tests', 'headless_runner.sh')],
		env: test_env,
		is_default: true
	)
else
	add_test_setup(
		'default',
		env: test_env,
		is_default: true
	)
endif

test('tests', tests_bin,
	is_parallel: false,
)

test('dock', dock_bin,
	is_parallel: false,
)
