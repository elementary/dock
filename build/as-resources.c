#include <gio/gio.h>

#if defined (__ELF__) && ( __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 6))
# define SECTION __attribute__ ((section (".gresource.as"), aligned (8)))
#else
# define SECTION
#endif

static const SECTION union { const guint8 data[312]; const double alignment; void * const ptr;}  as_resource_data = { {
  0x47, 0x56, 0x61, 0x72, 0x69, 0x61, 0x6e, 0x74, 
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
  0x18, 0x00, 0x00, 0x00, 0xac, 0x00, 0x00, 0x00, 
  0x00, 0x00, 0x00, 0x28, 0x05, 0x00, 0x00, 0x00, 
  0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 
  0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 
  0x04, 0x00, 0x00, 0x00, 0xd4, 0xb5, 0x02, 0x00, 
  0xff, 0xff, 0xff, 0xff, 0xac, 0x00, 0x00, 0x00, 
  0x01, 0x00, 0x4c, 0x00, 0xb0, 0x00, 0x00, 0x00, 
  0xb4, 0x00, 0x00, 0x00, 0xa0, 0xe2, 0x61, 0x8e, 
  0x04, 0x00, 0x00, 0x00, 0xb4, 0x00, 0x00, 0x00, 
  0x0b, 0x00, 0x4c, 0x00, 0xc0, 0x00, 0x00, 0x00, 
  0xc4, 0x00, 0x00, 0x00, 0x30, 0xaa, 0x68, 0x5d, 
  0x01, 0x00, 0x00, 0x00, 0xc4, 0x00, 0x00, 0x00, 
  0x05, 0x00, 0x4c, 0x00, 0xcc, 0x00, 0x00, 0x00, 
  0xd0, 0x00, 0x00, 0x00, 0xfb, 0xe2, 0x8a, 0x88, 
  0x02, 0x00, 0x00, 0x00, 0xd0, 0x00, 0x00, 0x00, 
  0x0f, 0x00, 0x76, 0x00, 0xe0, 0x00, 0x00, 0x00, 
  0x2f, 0x01, 0x00, 0x00, 0x7b, 0xa2, 0x78, 0x7c, 
  0x00, 0x00, 0x00, 0x00, 0x2f, 0x01, 0x00, 0x00, 
  0x03, 0x00, 0x4c, 0x00, 0x34, 0x01, 0x00, 0x00, 
  0x38, 0x01, 0x00, 0x00, 0x2f, 0x00, 0x00, 0x00, 
  0x04, 0x00, 0x00, 0x00, 0x65, 0x6c, 0x65, 0x6d, 
  0x65, 0x6e, 0x74, 0x61, 0x72, 0x79, 0x2f, 0x00, 
  0x02, 0x00, 0x00, 0x00, 0x64, 0x6f, 0x63, 0x6b, 
  0x2f, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 
  0x41, 0x70, 0x70, 0x6c, 0x69, 0x63, 0x61, 0x74, 
  0x69, 0x6f, 0x6e, 0x2e, 0x63, 0x73, 0x73, 0x00, 
  0x2e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 
  0x78, 0xda, 0x2b, 0xcf, 0xcc, 0x4b, 0xc9, 0x2f, 
  0x57, 0xa8, 0xe6, 0x52, 0x00, 0x82, 0xa4, 0xc4, 
  0xe4, 0xec, 0xf4, 0xa2, 0xfc, 0xd2, 0xbc, 0x14, 
  0xdd, 0xe4, 0xfc, 0x9c, 0xfc, 0x22, 0x2b, 0x85, 
  0x92, 0xa2, 0xc4, 0xbc, 0xe2, 0x82, 0xc4, 0xa2, 
  0xd4, 0xbc, 0x12, 0x6b, 0xae, 0x5a, 0x2e, 0x00, 
  0x76, 0x6a, 0x10, 0x02, 0x00, 0x00, 0x00, 0x00, 
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
  0x00, 0x28, 0x75, 0x75, 0x61, 0x79, 0x29, 0x69, 
  0x6f, 0x2f, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00
} };

static GStaticResource static_resource = { as_resource_data.data, sizeof (as_resource_data.data), NULL, NULL, NULL };
G_GNUC_INTERNAL GResource *as_get_resource (void);
GResource *as_get_resource (void)
{
  return g_static_resource_get_resource (&static_resource);
}
/*
  If G_HAS_CONSTRUCTORS is true then the compiler support *both* constructors and
  destructors, in a sane way, including e.g. on library unload. If not you're on
  your own.

  Some compilers need #pragma to handle this, which does not work with macros,
  so the way you need to use this is (for constructors):

  #ifdef G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA
  #pragma G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(my_constructor)
  #endif
  G_DEFINE_CONSTRUCTOR(my_constructor)
  static void my_constructor(void) {
   ...
  }

*/

#ifndef __GTK_DOC_IGNORE__

#if  __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 7)

#define G_HAS_CONSTRUCTORS 1

#define G_DEFINE_CONSTRUCTOR(_func) static void __attribute__((constructor)) _func (void);
#define G_DEFINE_DESTRUCTOR(_func) static void __attribute__((destructor)) _func (void);

#elif defined (_MSC_VER) && (_MSC_VER >= 1500)
/* Visual studio 2008 and later has _Pragma */

#define G_HAS_CONSTRUCTORS 1

/* We do some weird things to avoid the constructors being optimized
 * away on VS2015 if WholeProgramOptimization is enabled. First we
 * make a reference to the array from the wrapper to make sure its
 * references. Then we use a pragma to make sure the wrapper function
 * symbol is always included at the link stage. Also, the symbols
 * need to be extern (but not dllexport), even though they are not
 * really used from another object file.
 */

/* We need to account for differences between the mangling of symbols
 * for Win32 (x86) and x64 programs, as symbols on Win32 are prefixed
 * with an underscore but symbols on x64 are not.
 */
#ifdef _WIN64
#define G_MSVC_SYMBOL_PREFIX ""
#else
#define G_MSVC_SYMBOL_PREFIX "_"
#endif

#define G_DEFINE_CONSTRUCTOR(_func) G_MSVC_CTOR (_func, G_MSVC_SYMBOL_PREFIX)
#define G_DEFINE_DESTRUCTOR(_func) G_MSVC_DTOR (_func, G_MSVC_SYMBOL_PREFIX)

#define G_MSVC_CTOR(_func,_sym_prefix) \
  static void _func(void); \
  extern int (* _array ## _func)(void);              \
  int _func ## _wrapper(void) { _func(); g_slist_find (NULL,  _array ## _func); return 0; } \
  __pragma(comment(linker,"/include:" _sym_prefix # _func "_wrapper")) \
  __pragma(section(".CRT$XCU",read)) \
  __declspec(allocate(".CRT$XCU")) int (* _array ## _func)(void) = _func ## _wrapper;

#define G_MSVC_DTOR(_func,_sym_prefix) \
  static void _func(void); \
  extern int (* _array ## _func)(void);              \
  int _func ## _constructor(void) { atexit (_func); g_slist_find (NULL,  _array ## _func); return 0; } \
   __pragma(comment(linker,"/include:" _sym_prefix # _func "_constructor")) \
  __pragma(section(".CRT$XCU",read)) \
  __declspec(allocate(".CRT$XCU")) int (* _array ## _func)(void) = _func ## _constructor;

#elif defined (_MSC_VER)

#define G_HAS_CONSTRUCTORS 1

/* Pre Visual studio 2008 must use #pragma section */
#define G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA 1
#define G_DEFINE_DESTRUCTOR_NEEDS_PRAGMA 1

#define G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(_func) \
  section(".CRT$XCU",read)
#define G_DEFINE_CONSTRUCTOR(_func) \
  static void _func(void); \
  static int _func ## _wrapper(void) { _func(); return 0; } \
  __declspec(allocate(".CRT$XCU")) static int (*p)(void) = _func ## _wrapper;

#define G_DEFINE_DESTRUCTOR_PRAGMA_ARGS(_func) \
  section(".CRT$XCU",read)
#define G_DEFINE_DESTRUCTOR(_func) \
  static void _func(void); \
  static int _func ## _constructor(void) { atexit (_func); return 0; } \
  __declspec(allocate(".CRT$XCU")) static int (* _array ## _func)(void) = _func ## _constructor;

#elif defined(__SUNPRO_C)

/* This is not tested, but i believe it should work, based on:
 * http://opensource.apple.com/source/OpenSSL098/OpenSSL098-35/src/fips/fips_premain.c
 */

#define G_HAS_CONSTRUCTORS 1

#define G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA 1
#define G_DEFINE_DESTRUCTOR_NEEDS_PRAGMA 1

#define G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(_func) \
  init(_func)
#define G_DEFINE_CONSTRUCTOR(_func) \
  static void _func(void);

#define G_DEFINE_DESTRUCTOR_PRAGMA_ARGS(_func) \
  fini(_func)
#define G_DEFINE_DESTRUCTOR(_func) \
  static void _func(void);

#else

/* constructors not supported for this compiler */

#endif

#endif /* __GTK_DOC_IGNORE__ */

#ifdef G_HAS_CONSTRUCTORS

#ifdef G_DEFINE_CONSTRUCTOR_NEEDS_PRAGMA
#pragma G_DEFINE_CONSTRUCTOR_PRAGMA_ARGS(resource_constructor)
#endif
G_DEFINE_CONSTRUCTOR(resource_constructor)
#ifdef G_DEFINE_DESTRUCTOR_NEEDS_PRAGMA
#pragma G_DEFINE_DESTRUCTOR_PRAGMA_ARGS(resource_destructor)
#endif
G_DEFINE_DESTRUCTOR(resource_destructor)

#else
#warning "Constructor not supported on this compiler, linking in resources will not work"
#endif

static void resource_constructor (void)
{
  g_static_resource_init (&static_resource);
}

static void resource_destructor (void)
{
  g_static_resource_fini (&static_resource);
}
