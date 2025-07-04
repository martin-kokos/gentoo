# Copyright 2020-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: verify-sig.eclass
# @MAINTAINER:
# Michał Górny <mgorny@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Eclass to verify upstream signatures on distfiles
# @DESCRIPTION:
# verify-sig eclass provides a streamlined approach to verifying
# upstream signatures on distfiles.  Its primary purpose is to permit
# developers to easily verify signatures while bumping packages.
# The eclass removes the risk of developer forgetting to perform
# the verification, or performing it incorrectly, e.g. due to additional
# keys in the local keyring.  It also permits users to verify
# the developer's work.
#
# To use the eclass, start by packaging the upstream's key
# as sec-keys/openpgp-keys-*.  Then inherit the eclass, add detached
# signatures to SRC_URI and set VERIFY_SIG_OPENPGP_KEY_PATH.  The eclass
# provides verify-sig USE flag to toggle the verification.
#
# If you need to use signify, you may want to copy distfiles into WORKDIR to
# work around "Too many levels of symbolic links" error.
#
# A more complete guide can be found at:
# https://mgorny.pl/articles/verify-sig-by-example.html
#
# @EXAMPLE:
# Example use:
#
# @CODE
# inherit verify-sig
#
# SRC_URI="https://example.org/${P}.tar.gz
#   verify-sig? ( https://example.org/${P}.tar.gz.sig )"
# BDEPEND="
#   verify-sig? ( sec-keys/openpgp-keys-example )"
#
# VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/example.asc
# @CODE

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_VERIFY_SIG_ECLASS} ]]; then
_VERIFY_SIG_ECLASS=1

inherit eapi9-pipestatus

IUSE="verify-sig"

# @ECLASS_VARIABLE: VERIFY_SIG_METHOD
# @PRE_INHERIT
# @DESCRIPTION:
# Signature verification method to use.  The allowed value are:
#
#  - minisig -- verify signatures with (base64) Ed25519 public key using app-crypt/minisign
#  - openpgp -- verify PGP signatures using app-crypt/gnupg (the default)
#  - sigstore -- verify signatures using dev-python/sigstore
#  - signify -- verify signatures with Ed25519 public key using app-crypt/signify
: "${VERIFY_SIG_METHOD:=openpgp}"

case ${VERIFY_SIG_METHOD} in
	minisig)
		BDEPEND="verify-sig? ( app-crypt/minisign )"
		;;
	openpgp)
		BDEPEND="
			verify-sig? (
				app-crypt/gnupg
				>=app-portage/gemato-20
			)
		"
		;;
	signify)
		BDEPEND="verify-sig? ( app-crypt/signify )"
		;;
	sigstore)
		BDEPEND="
			verify-sig? (
				dev-python/sigstore
				sec-keys/sigstore-trusted-root
			)
		"
		;;
	*)
		die "${ECLASS}: unknown method '${VERIFY_SIG_METHOD}'"
		;;
esac

# @ECLASS_VARIABLE: VERIFY_SIG_OPENPGP_KEY_PATH
# @DEFAULT_UNSET
# @DESCRIPTION:
# Path to key bundle used to perform the verification.  This is required
# when using default src_unpack.  Alternatively, the key path can be
# passed directly to the verification functions.
#
# The value of BROOT will be prepended to this path automatically.
#
# This variable is also used for non-OpenPGP signatures.  The name
# contains "OPENPGP" for historical reasons.  It is not used
# for sigstore, since it uses a single trusted root.

# @ECLASS_VARIABLE: VERIFY_SIG_CERT_IDENTITY
# @DEFAULT_UNSET
# @DESCRIPTION:
# --cert-identity passed to sigstore invocation.

# @ECLASS_VARIABLE: VERIFY_SIG_CERT_OIDC_ISSUER
# @DEFAULT_UNSET
# @DESCRIPTION:
# --cert-oidc-issuer passed to sigstore invocation.

# @ECLASS_VARIABLE: VERIFY_SIG_OPENPGP_KEYSERVER
# @DEFAULT_UNSET
# @DESCRIPTION:
# Keyserver used to refresh keys.  If not specified, the keyserver
# preference from the key will be respected.  If no preference
# is specified by the key, the GnuPG default will be used.
#
# Supported for OpenPGP only.

# @ECLASS_VARIABLE: VERIFY_SIG_OPENPGP_KEY_REFRESH
# @USER_VARIABLE
# @DESCRIPTION:
# Attempt to refresh keys via WKD/keyserver.  Set it to "yes"
# in make.conf to enable.  Note that this requires working Internet
# connection.
#
# Supported for OpenPGP and sigstore.
: "${VERIFY_SIG_OPENPGP_KEY_REFRESH:=no}"

# @FUNCTION: verify-sig_verify_detached
# @USAGE: <file> <sig-file> [<key-file>]
# @DESCRIPTION:
# Read the detached signature from <sig-file> and verify <file> against
# it.  <key-file> can either be passed directly, or it defaults
# to VERIFY_SIG_OPENPGP_KEY_PATH.  The function dies if verification
# fails.
verify-sig_verify_detached() {
	local file=${1}
	local sig=${2}
	local key=${3}

	if [[ ${VERIFY_SIG_METHOD} == sigstore ]]; then
		if [[ -n ${key:-${VERIFY_SIG_OPENPGP_KEY_PATH}} ]]; then
			die "${FUNCNAME}: key unexpectedly specified for sigstore"
		fi
		if [[ -z ${VERIFY_SIG_CERT_IDENTITY} ]]; then
			die "${FUNCNAME}: VERIFY_SIG_CERT_IDENTITY must be specified for sigstore"
		fi
		if [[ -z ${VERIFY_SIG_CERT_OIDC_ISSUER} ]]; then
			die "${FUNCNAME}: VERIFY_SIG_CERT_OIDC_ISSUER must be specified for sigstore"
		fi
	elif [[ -z ${key} ]]; then
		if [[ -z ${VERIFY_SIG_OPENPGP_KEY_PATH} ]]; then
			die "${FUNCNAME}: no key passed and VERIFY_SIG_OPENPGP_KEY_PATH unset"
		else
			key="${BROOT}${VERIFY_SIG_OPENPGP_KEY_PATH}"
		fi
	fi

	local extra_args=()
	if [[ -n ${VERIFY_SIG_OPENPGP_KEYSERVER+1} ]]; then
		[[ ${VERIFY_SIG_METHOD} == openpgp ]] ||
			die "${FUNCNAME}: VERIFY_SIG_OPENPGP_KEYSERVER is not supported"

		extra_args+=(
			--keyserver "${VERIFY_SIG_OPENPGP_KEYSERVER}"
		)
	fi

	# GPG upstream knows better than to follow the spec, so we can't
	# override this directory.  However, there is a clean fallback
	# to GNUPGHOME.
	addpredict /run/user

	local filename=${file##*/}
	[[ ${file} == - ]] && filename='(stdin)'
	einfo "Verifying ${filename} ..."
	case ${VERIFY_SIG_METHOD} in
		minisig)
			minisign "${extra_args[@]}" \
				-V -P "$(<"${key}")" -x "${sig}" -m "${file}" ||
				die "minisig signature verification failed"
			;;
		openpgp)
			if [[ ${VERIFY_SIG_OPENPGP_KEY_REFRESH} != yes ]]; then
				extra_args+=( -R )
			fi

			# gpg can't handle very long TMPDIR
			# https://bugs.gentoo.org/854492
			local -x TMPDIR=/tmp
			gemato openpgp-verify-detached -K "${key}" \
				"${extra_args[@]}" --no-require-all-good \
				"${sig}" "${file}" ||
				die "PGP signature verification failed"
			;;
		signify)
			signify "${extra_args[@]}" \
				-V -p "${key}" -m "${file}" -x "${sig}" ||
				die "Signify signature verification failed"
			;;
		sigstore)
			if [[ ${VERIFY_SIG_OPENPGP_KEY_REFRESH} != yes ]]; then
				extra_args+=( --offline )
			fi

			cp -r "${BROOT}"/usr/share/sigstore-gentoo/{.cache,.local} \
				"${HOME}"/ || die
			sigstore verify identity "${extra_args[@]}" \
				--bundle "${sig}" \
				--cert-identity "${VERIFY_SIG_CERT_IDENTITY}" \
				--cert-oidc-issuer "${VERIFY_SIG_CERT_OIDC_ISSUER}" \
				"${file}" ||
				die "Sigstore signature verification failed"
			;;
		*)
			die "${FUNCNAME} not supported with ${VERIFY_SIG_METHOD}"
			;;
	esac
}

# @FUNCTION: verify-sig_verify_message
# @USAGE: <file> <output-file> [<key-file>]
# @DESCRIPTION:
# Verify that the file ('-' for stdin) contains a valid, signed PGP
# message and write the message into <output-file> ('-' for stdout).
# <key-file> can either be passed directly, or it defaults
# to VERIFY_SIG_OPENPGP_KEY_PATH.  The function dies if verification
# fails.  Note that using output from <output-file> is important as it
# prevents the injection of unsigned data.
verify-sig_verify_message() {
	local file=${1}
	local output_file=${2}
	local key=${3}

	if [[ -z ${key} ]]; then
		if [[ -z ${VERIFY_SIG_OPENPGP_KEY_PATH} ]]; then
			die "${FUNCNAME}: no key passed and VERIFY_SIG_OPENPGP_KEY_PATH unset"
		else
			key="${BROOT}${VERIFY_SIG_OPENPGP_KEY_PATH}"
		fi
	fi

	local extra_args=()
	[[ ${VERIFY_SIG_OPENPGP_KEY_REFRESH} == yes ]] || extra_args+=( -R )
	if [[ -n ${VERIFY_SIG_OPENPGP_KEYSERVER+1} ]]; then
		[[ ${VERIFY_SIG_METHOD} == openpgp ]] ||
			die "${FUNCNAME}: VERIFY_SIG_OPENPGP_KEYSERVER is not supported"

		extra_args+=(
			--keyserver "${VERIFY_SIG_OPENPGP_KEYSERVER}"
		)
	fi

	# GPG upstream knows better than to follow the spec, so we can't
	# override this directory.  However, there is a clean fallback
	# to GNUPGHOME.
	addpredict /run/user

	local filename=${file##*/}
	[[ ${file} == - ]] && filename='(stdin)'
	einfo "Verifying ${filename} ..."
	case ${VERIFY_SIG_METHOD} in
		minisig)
			minisign -V -P "$(<"${key}")" -x "${sig}" -o "${output_file}" -m "${file}" ||
				die "minisig signature verification failed"
			;;
		openpgp)
			# gpg can't handle very long TMPDIR
			# https://bugs.gentoo.org/854492
			local -x TMPDIR=/tmp
			gemato gpg-wrap -K "${key}" "${extra_args[@]}" -- \
				gpg --verify --output="${output_file}" "${file}" ||
				die "PGP signature verification failed"
			;;
		signify)
			signify -V -e -p "${key}" -m "${output_file}" -x "${file}" ||
				die "Signify signature verification failed"
			;;
		*)
			die "${FUNCNAME} not supported with ${VERIFY_SIG_METHOD}"
			;;
	esac
}

# @FUNCTION: verify-sig_verify_unsigned_checksums
# @USAGE: <checksum-file> <format> <files>
# @DESCRIPTION:
# Verify the checksums for all files listed in the space-separated list
# <files> (akin to ${A}) using a <checksum-file>.  <format> specifies
# the checksum file format.  <checksum-file> can be "-" for stdin.
#
# The following formats are supported:
#  - sha256 -- sha256sum (<hash> <filename>)
#  - openssl-dgst -- openssl dgst (<algo>(<filename>)=<hash>)
#
# The function dies if one of the files does not match checksums or
# is missing from the checksum file.
#
# Note that this function itself can only verify integrity of the files.
# In order to verify their authenticity, the <checksum-file> must
# be verified against a signature first, e.g. using
# verify-sig_verify_detached.  If it contains inline signature, use
# verify-sig_verify_signed_checksums instead.
verify-sig_verify_unsigned_checksums() {
	local checksum_file=${1}
	local format=${2}
	local files=()
	read -r -d '' -a files <<<"${3}"
	local chksum_prog chksum_len algo=${format}

	case ${format} in
		sha256)
			chksum_len=64
			;;
		openssl-dgst)
			;;
		*)
			die "${FUNCNAME}: unknown checksum format ${format}"
			;;
	esac

	[[ ${checksum_file} == - ]] && checksum_file=/dev/stdin
	local line checksum filename junk ret=0 count=0
	local -A verified
	while read -r line; do
		if [[ ${line} == "-----BEGIN"* ]]; then
			die "${FUNCNAME}: PGP armor found, use verify-sig_verify_signed_checksums instead"
		fi

		case ${format} in
			sha256)
				read -r checksum filename junk <<<"${line}"
				[[ ${#checksum} -ne ${chksum_len} ]] && continue
				[[ -n ${checksum//[0-9a-f]} ]] && continue
				[[ -n ${junk} ]] && continue
				;;
			openssl-dgst)
				[[ ${line} != *"("*")="* ]] && continue
				checksum=${line##*)=}
				algo=${line%%(*}
				filename=${line#*(}
				filename=${filename%)=*}
				;;
		esac

		if ! has "${filename}" "${files[@]}"; then
			continue
		fi

		if "${algo,,}sum" -c --strict - <<<"${checksum} ${filename}"; then
			verified["${filename}"]=1
		else
			ret=1
		fi
	done < "${checksum_file}"

	[[ ${ret} -eq 0 ]] ||
		die "${FUNCNAME}: at least one file did not verify successfully"
	[[ ${#verified[@]} -eq ${#files[@]} ]] ||
		die "${FUNCNAME}: checksums for some of the specified files were missing"
}

# @FUNCTION: _gpg_verify_signed_checksums
# @INTERNAL
# @USAGE: <checksum-file> <algo> <files> [<key-file>]
# @DESCRIPTION:
# GnuPG-specific function to verify a signed checksums list.
_gpg_verify_signed_checksums() {
	local checksum_file=${1}
	local algo=${2}
	local files=${3}
	local key=${4}

	verify-sig_verify_unsigned_checksums - "${algo}" "${files}" < <(
		verify-sig_verify_message "${checksum_file}" - "${key}"
	)
}

# @FUNCTION: verify-sig_verify_signed_checksums
# @USAGE: <checksum-file> <algo> <files> [<key-file>]
# @DESCRIPTION:
# Verify the checksums for all files listed in the space-separated list
# <files> (akin to ${A}) using a signed <checksum-file>.  <algo> specifies
# the checksum algorithm (e.g. sha256).  <key-file> can either be passed
# directly, or it defaults to VERIFY_SIG_OPENPGP_KEY_PATH.
#
# The function dies if signature verification fails, the checksum file
# contains unsigned data, one of the files do not match checksums or
# are missing from the checksum file.
verify-sig_verify_signed_checksums() {
	local checksum_file=${1}
	local algo=${2}
	local files=()
	read -r -d '' -a files <<<"${3}"
	local key=${4}

	if [[ -z ${key} ]]; then
		if [[ -z ${VERIFY_SIG_OPENPGP_KEY_PATH} ]]; then
			die "${FUNCNAME}: no key passed and VERIFY_SIG_OPENPGP_KEY_PATH unset"
		else
			key="${BROOT}${VERIFY_SIG_OPENPGP_KEY_PATH}"
		fi
	fi

	case ${VERIFY_SIG_METHOD} in
		openpgp)
			_gpg_verify_signed_checksums \
				"${checksum_file}" "${algo}" "${files[*]}" "${key}"
			;;
		signify)
			signify -C -p "${key}" \
				-x "${checksum_file}" "${files[@]}" ||
				die "Signify signature verification failed"
			;;
		*)
			die "${FUNCNAME} not supported with ${VERIFY_SIG_METHOD}"
			;;
	esac
}

# @FUNCTION: verify-sig_uncompress_verify_unpack
# @USAGE: <compressed-tar> <sig-file> [<key-file>]
# @DESCRIPTION:
# Uncompress the <compressed-tar> tarball, verify the uncompressed
# archive against the signature in <sig-file> and unpack it.  This is
# useful for kernel.org packages that sign the uncompressed tarball
# instead of the compressed archive.  <key-file> can either be passed
# directly, or it defaults to VERIFY_SIG_OPENPGP_KEY_PATH.  The function
# dies if verification or any of the unpacking steps fail.
verify-sig_uncompress_verify_unpack() {
	local file=${1}
	local unpacker

	# TODO: integrate with unpacker.eclass somehow?
	case ${file} in
		*.tar.xz)
			unpacker=( xz -cd )
			;;
		*)
			die "${FUNCNAME}: only .tar.xz archives are supported at the moment"
			;;
	esac

	einfo "Unpacking ${file} ..."
	verify-sig_verify_detached - "${@:2}" < <(
		"${unpacker[@]}" "${file}" | tee >(tar -xf - || die)
		pipestatus || die
	)
}

# @FUNCTION: verify-sig_src_unpack
# @DESCRIPTION:
# Default src_unpack override that verifies signatures for all
# distfiles if 'verify-sig' flag is enabled.  The function dies if any
# of the signatures fails to verify or if any distfiles are not signed.
# Please write src_unpack() yourself if you need to perform partial
# verification.
verify-sig_src_unpack() {
	if use verify-sig; then
		local f suffix found
		local distfiles=() signatures=() nosigfound=() straysigs=()

		# find all distfiles and signatures, and combine them
		for f in ${A}; do
			found=
			for suffix in .asc .sig .minisig .sigstore; do
				if [[ ${f} == *${suffix} ]]; then
					signatures+=( "${f}" )
					found=sig
					break
				else
					if has "${f}${suffix}" ${A}; then
						distfiles+=( "${f}" )
						found=dist+sig
						break
					fi
				fi
			done
			if [[ ! ${found} ]]; then
				nosigfound+=( "${f}" )
			fi
		done

		# check if all distfiles are signed
		if [[ ${#nosigfound[@]} -gt 0 ]]; then
			eerror "The following distfiles lack detached signatures:"
			for f in "${nosigfound[@]}"; do
				eerror "  ${f}"
			done
			die "Unsigned distfiles found"
		fi

		# check if there are no stray signatures
		for f in "${signatures[@]}"; do
			if ! has "${f%.*}" "${distfiles[@]}"; then
				straysigs+=( "${f}" )
			fi
		done
		if [[ ${#straysigs[@]} -gt 0 ]]; then
			eerror "The following signatures do not match any distfiles:"
			for f in "${straysigs[@]}"; do
				eerror "  ${f}"
			done
			die "Unused signatures found"
		fi

		# now perform the verification
		for f in "${signatures[@]}"; do
			verify-sig_verify_detached \
				"${DISTDIR}/${f%.*}" "${DISTDIR}/${f}"
		done
	fi

	# finally, unpack the distfiles
	default_src_unpack
}

fi

EXPORT_FUNCTIONS src_unpack
