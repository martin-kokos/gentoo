# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit apache-module autotools flag-o-matic

DESCRIPTION="mod_musicindex allows nice displaying of directories containing music files"
HOMEPAGE="http://hacks.slashdirt.org/sw/musicindex/"
SRC_URI="http://hacks.slashdirt.org/musicindex/${P}.tar.gz
	http://validator.w3.org/feed/images/valid-rss.png -> ${P}_valid-rss.png
	http://jigsaw.w3.org/css-validator/images/vcss -> ${P}_vcss
	http://www.w3.org/Icons/valid-xhtml11 -> ${P}_valid-xhtml11"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="+mp3 +mp4 +flac +vorbis +cache mysql archive"

DEPEND="mp3? ( media-libs/libmad media-libs/libid3tag:= )
	mp4? ( media-libs/libmp4v2:0 )
	flac? ( media-libs/flac:= )
	vorbis? ( media-libs/libvorbis )
	archive? ( app-arch/libarchive:= )
	mysql? ( dev-db/mysql-connector-c:0= )"
RDEPEND="${DEPEND}
	dev-build/libtool"

APACHE2_MOD_CONF="50_${PN}"
APACHE2_MOD_DEFINE="MUSICINDEX"
DOCS=( AUTHORS BUGS ChangeLog README UPGRADING )

PATCHES=(
	"${FILESDIR}"/${P}-slibtool.patch #778566
)

need_apache2

pkg_setup() {
	_init_apache2_late
}

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	# bug #944206
	append-cflags -std=gnu17

	econf \
		--with-vorbis-libraries="${ESYSROOT}/usr/$(get_libdir)" \
		--with-libFLAC-libraries="${ESYSROOT}/usr/$(get_libdir)" \
		$(use_enable mp3) \
		$(use_enable mp4) \
		$(use_enable flac) \
		$(use_enable vorbis) \
		$(use_enable archive) \
		$(use_enable cache filecache) \
		$(use_enable mysql mysqlcache)
}

src_compile() {
	default
}

src_install() {
	default
	apache-module_src_install

	# install W3C images
	insinto /usr/share/mod_musicindex
	newins "${DISTDIR}/${P}_valid-rss.png" valid-rss.png
	newins "${DISTDIR}/${P}_valid-xhtml11" valid-xhtml11
	newins "${DISTDIR}/${P}_vcss" vcss

	find "${ED}" -type f -name "*.la" -delete || die
}
