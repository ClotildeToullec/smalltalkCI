#!/bin/bash

set -e

# ==============================================================================
# Set paths and files
# ==============================================================================
readonly VM_DOWNLOAD="https://www.hpi.uni-potsdam.de/hirschfeld/artefacts/filetreeci/vms"
readonly IMAGE_DOWNLOAD="https://www.hpi.uni-potsdam.de/hirschfeld/artefacts/filetreeci/images"

# Optional environment variables
[[ -z "${baseline_group}" ]] && export baseline_group="TravisCI"
[[ -z "${exclude_categories}" ]] && exclude_categories="nil"
[[ -z "${exclude_classes}" ]] && exclude_classes="nil"
[[ -z "${force_update}" ]] && force_update="false"
[[ -z "${keep_open}" ]] && keep_open="false"
if [[ -z "${run_script}" ]]; then
    run_script="${SMALLTALK_CI_HOME}/squeak/run.st"
else
    run_script="${project_home}/${run_script}"
fi
# ==============================================================================

# ==============================================================================
# Check and specify Squeak image
# ==============================================================================
case "$SMALLTALK" in
    "Squeak-trunk"|"Squeak-Trunk"|"SqueakTrunk")
        readonly IMAGE_TAR="Squeak-Trunk.tar.gz"
        readonly SPUR_IMAGE=true
        ;;
    "Squeak-5.0"|"Squeak5.0")
        readonly IMAGE_TAR="Squeak-5.0.tar.gz"
        readonly SPUR_IMAGE=true
        ;;
    "Squeak-4.6"|"Squeak4.6")
        readonly IMAGE_TAR="Squeak-4.6.tar.gz"
        readonly SPUR_IMAGE=false
        ;;
    "Squeak-4.5"|"Squeak4.5")
        readonly IMAGE_TAR="Squeak-4.5.tar.gz"
        readonly SPUR_IMAGE=false
        ;;
    *)
        print_error "Unsupported Squeak version '${SMALLTALK}'"
        exit 1
        ;;
esac
# ==============================================================================

# ==============================================================================
# Identify OS and select virtual machine
# ==============================================================================
case "$(uname -s)" in
    "Linux")
        print_info "Linux detected..."
        if [[ "${SPUR_IMAGE}" = true ]]; then
            readonly COG_VM_FILE_BASE="cog_linux_spur"
            readonly COG_VM="${SMALLTALK_CI_VMS}/cogspurlinux/bin/squeak"
        else
            readonly COG_VM_FILE_BASE="cog_linux"
            readonly COG_VM="${SMALLTALK_CI_VMS}/coglinux/bin/squeak"
        fi
        COG_VM_FILE="${COG_VM_FILE_BASE}.tar.gz"
        if [[ "${TRAVIS}" = "true" ]]; then
            COG_VM_FILE="${COG_VM_FILE_BASE}.min.tar.gz"
            readonly COG_VM_PARAM="-nosound -nodisplay"
        fi
        readonly COG_VM_FILE
        ;;
    "Darwin")
        print_info "OS X detected..."
        if [[ "${SPUR_IMAGE}" = true ]]; then
            readonly COG_VM_FILE_BASE="cog_osx_spur"
            readonly COG_VM="${SMALLTALK_CI_VMS}/CogSpur.app/Contents/MacOS/Squeak"
        else
            readonly COG_VM_FILE_BASE="cog_osx"
            readonly COG_VM="${SMALLTALK_CI_VMS}/Cog.app/Contents/MacOS/Squeak"
        fi
        readonly COG_VM_FILE="${COG_VM_FILE_BASE}.tar.gz"
        ;;
    *)
        print_error "Unsupported platform '$(uname -s)'"
        exit 1
        ;;
esac
# ==============================================================================

# ==============================================================================
# Download files accordingly if not available
# ==============================================================================
if [[ ! -f "${SMALLTALK_CI_CACHE}/${COG_VM_FILE}" ]]; then
    print_timed "Downloading virtual machine..."
    download_file "${VM_DOWNLOAD}/${COG_VM_FILE}" > "${SMALLTALK_CI_CACHE}/${COG_VM_FILE}"
    print_timed_result "Time to download virtual machine"
fi
if [[ ! -f "$COG_VM" ]]; then
    print_info "Extracting virtual machine..."
    tar xzf "${SMALLTALK_CI_CACHE}/${COG_VM_FILE}" -C "${SMALLTALK_CI_VMS}"
fi
if [[ ! -f "${SMALLTALK_CI_CACHE}/${IMAGE_TAR}" ]]; then
    print_timed "Downloading ${SMALLTALK} testing image..."
    download_file "${IMAGE_DOWNLOAD}/${IMAGE_TAR}" > "${SMALLTALK_CI_CACHE}/${IMAGE_TAR}"
    print_timed_result "Time to download ${SMALLTALK} testing image"
fi
# ==============================================================================

# ==============================================================================
# Extract image and run on virtual machine
# ==============================================================================
print_info "Extracting image..."
tar xzf "${SMALLTALK_CI_CACHE}/${IMAGE_TAR}" -C "${SMALLTALK_CI_BUILD}"

print_info "Load project into image and run tests..."
readonly VM_ARGS="${packages} ${baseline} ${baseline_group} ${exclude_categories} ${exclude_classes} ${force_update} ${keep_open}"
"${COG_VM}" $COG_VM_PARAM "${SMALLTALK_CI_IMAGE}" "${run_script}" $VM_ARGS || exit_status=$?
# ==============================================================================
