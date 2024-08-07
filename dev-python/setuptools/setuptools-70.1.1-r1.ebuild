# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# please keep this ebuild at EAPI 8 -- sys-apps/portage dep
EAPI=8

# please bump dev-python/ensurepip-setuptools along with this package!

DISTUTILS_USE_PEP517=standalone
PYTHON_TESTED=( python3_{10..13} pypy3 )
PYTHON_COMPAT=( "${PYTHON_TESTED[@]}" )
PYTHON_REQ_USE="xml(+)"

inherit distutils-r1 pypi

DESCRIPTION="Collection of extensions to Distutils"
HOMEPAGE="
	https://github.com/pypa/setuptools/
	https://pypi.org/project/setuptools/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~hppa ~ia64 ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

# check */_vendor/vendored.txt
RDEPEND="
	!!<dev-python/setuptools-rust-1.8.0
	>=dev-python/jaraco-text-3.7.0-r1[${PYTHON_USEDEP}]
	>=dev-python/more-itertools-8.12.0-r1[${PYTHON_USEDEP}]
	>=dev-python/ordered-set-4.0.2-r1[${PYTHON_USEDEP}]
	>=dev-python/packaging-24[${PYTHON_USEDEP}]
	>=dev-python/platformdirs-2.6.2-r1[${PYTHON_USEDEP}]
	>=dev-python/wheel-0.37.1-r1[${PYTHON_USEDEP}]
	$(python_gen_cond_dep '
		>=dev-python/tomli-2.0.1[${PYTHON_USEDEP}]
	' 3.10)
"
BDEPEND="
	${RDEPEND}
	test? (
		$(python_gen_cond_dep '
			>=dev-python/build-1.0.3[${PYTHON_USEDEP}]
			>=dev-python/ini2toml-0.14[${PYTHON_USEDEP}]
			>=dev-python/filelock-3.4.0[${PYTHON_USEDEP}]
			>=dev-python/jaraco-envs-2.2[${PYTHON_USEDEP}]
			>=dev-python/jaraco-path-3.2.0[${PYTHON_USEDEP}]
			dev-python/jaraco-test[${PYTHON_USEDEP}]
			dev-python/pip[${PYTHON_USEDEP}]
			dev-python/pip-run[${PYTHON_USEDEP}]
			dev-python/pyproject-hooks[${PYTHON_USEDEP}]
			dev-python/pytest[${PYTHON_USEDEP}]
			>=dev-python/pytest-home-0.5[${PYTHON_USEDEP}]
			dev-python/pytest-subprocess[${PYTHON_USEDEP}]
			dev-python/pytest-timeout[${PYTHON_USEDEP}]
			dev-python/pytest-xdist[${PYTHON_USEDEP}]
			>=dev-python/tomli-w-1.0.0[${PYTHON_USEDEP}]
			>=dev-python/virtualenv-20[${PYTHON_USEDEP}]
		' "${PYTHON_TESTED[@]}")
	)
"
# setuptools-scm is here because installing plugins apparently breaks stuff at
# runtime, so let's pull it early. See bug #663324.
#
# trove-classifiers are optionally used in validation, if they are
# installed.  Since we really oughtn't block them, let's always enforce
# the newest version for the time being to avoid errors.
PDEPEND="
	dev-python/setuptools-scm[${PYTHON_USEDEP}]
	>=dev-python/trove-classifiers-2024.7.2[${PYTHON_USEDEP}]
"

src_prepare() {
	local PATCHES=(
		# TODO: remove this when we're 100% PEP517 mode
		"${FILESDIR}/setuptools-62.4.0-py-compile.patch"
	)

	distutils-r1_src_prepare

	# breaks tests
	sed -i -e '/--import-mode/d' pytest.ini || die

	# remove bundled dependencies
	rm -r */_vendor || die

	# remove the ugly */extern hack that breaks on unvendored deps
	rm -r */extern || die
	find -name '*.py' -exec sed \
		-e 's:from \w*[.]\+extern ::' -e 's:\w*[.]\+extern[.]::' \
		-i {} + || die
}

python_test() {
	if ! has "${EPYTHON}" "${PYTHON_TESTED[@]/_/.}"; then
		return
	fi

	local EPYTEST_DESELECT=(
		# network
		# TODO: see if PRE_BUILT_SETUPTOOLS_* helps
		setuptools/tests/config/test_apply_pyprojecttoml.py::test_apply_pyproject_equivalent_to_setupcfg
		setuptools/tests/integration/test_pip_install_sdist.py::test_install_sdist
		setuptools/tests/test_build_meta.py::test_legacy_editable_install
		setuptools/tests/test_distutils_adoption.py
		setuptools/tests/test_editable_install.py
		setuptools/tests/test_setuptools.py::test_its_own_wheel_does_not_contain_tests
		setuptools/tests/test_virtualenv.py::test_clean_env_install
		setuptools/tests/test_virtualenv.py::test_no_missing_dependencies
		setuptools/tests/test_virtualenv.py::test_test_command_install_requirements
		# TODO
		setuptools/tests/config/test_setupcfg.py::TestConfigurationReader::test_basic
		setuptools/tests/config/test_setupcfg.py::TestConfigurationReader::test_ignore_errors
		setuptools/tests/test_extern.py::test_distribution_picklable
		# expects bundled deps in virtualenv
		setuptools/tests/config/test_apply_pyprojecttoml.py::TestMeta::test_example_file_in_sdist
		setuptools/tests/config/test_apply_pyprojecttoml.py::TestMeta::test_example_file_not_in_wheel
		# fails if python-xlib is installed
		setuptools/tests/test_easy_install.py::TestSetupRequires::test_setup_requires_with_allow_hosts
		# TODO, probably some random package
		setuptools/tests/config/test_setupcfg.py::TestOptions::test_cmdclass
		# Internet, sigh
		setuptools/tests/test_integration.py
		# flaky
		setuptools/tests/test_easy_install.py::TestSetupRequires::test_setup_requires_with_transitive_extra_dependency
		setuptools/tests/test_easy_install.py::TestSetupRequires::test_setup_requires_with_distutils_command_dep
	)

	case ${EPYTHON} in
		python3.12)
			EPYTEST_DESELECT+=(
				# TODO
				setuptools/tests/test_easy_install.py::TestSetupRequires::test_setup_requires_with_distutils_command_dep
				setuptools/tests/test_easy_install.py::TestSetupRequires::test_setup_requires_with_transitive_extra_dependency
			)
	esac

	local EPYTEST_XDIST=1
	epytest -o tmp_path_retention_policy=all setuptools
}
