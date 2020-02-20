#!/bin/sh

mkdir -p "${DESTDIR}/${MESON_INSTALL_PREFIX}/share/gtk-doc/html/"
cp -r "${MESON_BUILD_ROOT}/docs/vala-doc/plank" "${DESTDIR}/${MESON_INSTALL_PREFIX}/share/gtk-doc/html/"
