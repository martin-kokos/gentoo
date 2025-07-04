# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

MY_P="${PN}_$(ver_rs 1- '')_linux"

DESCRIPTION="UCI-only chess engine"
HOMEPAGE="https://arctrix.com/nas/chess/fruit/"
SRC_URI="https://arctrix.com/nas/chess/${PN}/${MY_P}.zip"
S="${WORKDIR}/${MY_P}/src"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

BDEPEND="app-arch/unzip"

src_prepare() {
	default

	sed -i "s|book_small|${EPREFIX}/usr/share/${PN}/book_small|" option.cpp || die
}

src_compile() {
	# -Werror=odr
	# https://bugs.gentoo.org/941075
	#
	# Went commercial, archived by a third-party source in 2007. Nowhere to report.
	filter-lto

	emake CXX="$(tc-getCXX)" CXXFLAGS="${CXXFLAGS} ${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
}

src_install() {
	dobin ${PN}

	insinto /usr/share/${PN}
	doins ../book_small.bin

	dodoc ../{readme,technical_10}.txt
}
