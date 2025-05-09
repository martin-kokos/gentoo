# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=flit
PYTHON_COMPAT=( pypy3 pypy3_11 python3_{10..13} )

inherit distutils-r1 pypi

DESCRIPTION="Python QR Code and Micro QR Code encoder"
HOMEPAGE="
	https://pypi.org/project/segno/
	https://github.com/heuer/segno/
"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

BDEPEND="
	test? (
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/pypng[${PYTHON_USEDEP}]
		dev-python/pyzbar[${PYTHON_USEDEP}]
	)
"

distutils_enable_tests pytest

EPYTEST_DESELECT=(
	# requires qrcode-artistic
	tests/test_plugin.py::test_plugin
)

src_prepare() {
	distutils-r1_src_prepare

	# https://github.com/heuer/segno/pull/147
	mv data/{usr/share,share} || die
}
