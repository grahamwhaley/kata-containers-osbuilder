#!/bin/bash
#
# Copyright (c) 2018 HyperHQ Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -e

script_name="${0##*/}"
script_dir="$(dirname $(readlink -f $0))"

if [ -n "$DEBUG" ] ; then
	set -x
fi

SCRIPT_NAME="${0##*/}"
INITRD_IMAGE="${INITRD_IMAGE:-kata-initrd.img}"
AGENT_BIN=${AGENT_BIN:-kata-agent}
AGENT_INIT=${AGENT_INIT:-no}

die()
{
	local msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

OK()
{
	local msg="$*"
	echo "[OK] ${msg}" >&2
}

info()
{
	local msg="$*"
	echo "INFO: ${msg}"
}

usage()
{
	error="${1:-0}"
	cat <<EOT
Usage: ${SCRIPT_NAME} [options] <rootfs-dir>
	This script creates a Kata Containers initrd image file based on the
	<rootfs-dir> directory.

Options:
	-h Show help
	-o Set the path where the generated image file is stored.
	   DEFAULT: the path stored in the environment variable INITRD_IMAGE

Extra environment variables:
	AGENT_BIN:  use it to change the expected agent binary name
		    DEFAULT: kata-agent
	AGENT_INIT: use kata agent as init process
		    DEFAULT: no
	USE_DOCKER: If set, the image builds in a Docker Container. Setting
		    this variable requires Docker.
	            DEFAULT: not set
EOT
exit "${error}"
}

while getopts "ho:" opt
do
	case "$opt" in
		h)	usage ;;
		o)	INITRD_IMAGE="${OPTARG}" ;;
	esac
done

shift $(( $OPTIND - 1 ))

ROOTFS="$1"


[ -n "${ROOTFS}" ] || usage
[ -d "${ROOTFS}" ] || die "${ROOTFS} is not a directory"

ROOTFS=$(readlink -f ${ROOTFS})
IMAGE_DIR=$(dirname ${INITRD_IMAGE})
IMAGE_DIR=$(readlink -f ${IMAGE_DIR})
IMAGE_NAME=$(basename ${INITRD_IMAGE})

# The kata rootfs image expects init to be installed
init="${ROOTFS}/sbin/init"
[ -x "${init}" ] || [ -L ${init} ] || die "/sbin/init is not installed in ${ROOTFS}"
OK "init is installed"
[ "${AGENT_INIT}" == "yes" ] || [ -x "${ROOTFS}/usr/bin/${AGENT_BIN}" ] || \
	die "/usr/bin/${AGENT_BIN} is not installed in ${ROOTFS}
	use AGENT_BIN env variable to change the expected agent binary name"
OK "Agent is installed"

[ "$(id -u)" -eq 0 ] || die "$0: must be run as root"

# initramfs expects /init
mv -f ${init} "${ROOTFS}/init"

info "Creating ${IMAGE_DIR}/${IMAGE_NAME} based on rootfs at ${ROOTFS}"
( cd "${ROOTFS}" && find . | cpio -H newc -o | gzip -9 ) > "${IMAGE_DIR}"/"${IMAGE_NAME}"
