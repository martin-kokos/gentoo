# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
DISTUTILS_USE_PEP517=setuptools
inherit distutils-r1 git-r3

DESCRIPTION="Arch testing tool"
HOMEPAGE="https://github.com/gentoo/tatt"
EGIT_REPO_URI="https://anongit.gentoo.org/git/proj/tatt.git
	https://github.com/gentoo/tatt.git"

LICENSE="GPL-2"
SLOT="0"
IUSE="+templates"

RDEPEND="
	app-portage/eix
	app-portage/gentoolkit[${PYTHON_USEDEP}]
	app-portage/nattka[${PYTHON_USEDEP}]
	dev-python/configobj[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	www-client/pybugz
"

python_install_all() {
	distutils-r1_python_install_all
	if use templates; then
		insinto "/usr/share/${PN}"
		doins -r templates
	fi
	doman tatt.1
	doman tatt.5
}
