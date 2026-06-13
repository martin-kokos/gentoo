# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Library for reading AES SOFA (Spatially Oriented Format for Acoustics) files."
HOMEPAGE="https://github.com/hoene/libmysofa"
SRC_URI="https://github.com/hoene/libmysofa/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="
	test? ( dev-util/cunit )"

PATCHES=(
	# tests fail on 1.3.4 but passing on master - https://github.com/hoene/libmysofa/issues/243
	"${FILESDIR}/0001-optimized-code-of-btree-loop.patch"
)

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTS=$(usex test)
	)
	cmake_src_configure
}
