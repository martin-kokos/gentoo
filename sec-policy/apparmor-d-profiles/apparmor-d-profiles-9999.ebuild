# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="A collection of 3d party AppArmor profiles"
HOMEPAGE="https://apparmor.pujol.io/"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

RESTRICT="test"

EGIT_REPO_URI="https://github.com/roddhjav/apparmor.d.git"

BDEPEND="dev-lang/go"
RDEPEND=">=sec-policy/apparmor-profiles-4.0.0"

src_prepare() {

	# Add to allowed distros
	sed -e 's#\tcase "arch", "opensuse":#\tcase "arch", "opensuse", "gentoo":#' -i pkg/prebuild/prepare/configure.go || die

	default

}
pkg_postinst() {
	elog
	elog "Due to the large number of rules it is recommended to enable"
	elog "following options in your /etc/apparmor/parser.conf:"
	elog
	elog "write-cache"
	elog "Optimize=compress-fast"
	elog
}
