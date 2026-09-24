#!/usr/bin/env bash

# CI compatibility-build helper for Eigen 3.4 and Eigen 5.
#
# This script builds the project for two target platforms (Linux and
# Windows cross-compilation) against two Eigen versions, resulting in
# a 2x2 compatibility matrix:
#
#   Linux          + Eigen 3.4
#   Linux          + Eigen 5
#   Windows-cross  + Eigen 3.4
#   Windows-cross  + Eigen 5
#
# The script creates an isolated vcpkg manifest, install tree, binary
# cache, and CMake build directory for each platform/Eigen combination
# to avoid cross-contamination between configurations.
#
# It is intended as a CI/compatibility-build helper rather than the
# main project build script. The script uses BITBUCKET_CLONE_DIR, so it
# was originally designed for a Bitbucket Pipelines environment.
#
# The script is not technically tied to Bitbucket. To use it from
# GitHub Actions, the simplest approach is to provide the equivalent
# repository-root variable before invoking the script:
#
#   export BITBUCKET_CLONE_DIR="${GITHUB_WORKSPACE}"
#
# Alternatively, BITBUCKET_CLONE_DIR can be replaced throughout this
# script with GITHUB_WORKSPACE. No other part of the script depends on
# Bitbucket-specific functionality.
#
# Example GitHub Actions usage:
#
#   - name: Build Eigen compatibility matrix
#     run: |
#       export BITBUCKET_CLONE_DIR="${GITHUB_WORKSPACE}"
#       ./scripts/ci/compile_vcpkg_eigen_matrix.sh linux 3.4
#
# To test the complete 2x2 matrix in GitHub Actions, the workflow can
# use a matrix such as:
#
#   strategy:
#     matrix:
#       target_platform: [linux, windows-cross]
#       eigen_lane: ["3.4", "5"]
#
# and invoke:
#
#   ./scripts/ci/compile_vcpkg_eigen_matrix.sh \
#     "${{ matrix.target_platform }}" \
#     "${{ matrix.eigen_lane }}"
#
# Note that the GitHub Actions workflow currently used by the project
# does not invoke this script directly. This script should therefore be
# considered a standalone Eigen compatibility-build helper unless it is
# explicitly integrated into a CI workflow.
#
# Usage:
#   ./compile_vcpkg_eigen_matrix.sh <linux|windows-cross> <3.4|5>
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <linux|windows-cross> <3.4|5>" >&2
    exit 2
fi

target_platform="$1"
eigen_lane="$2"

case "$target_platform" in
    linux)
        triplet="x64-linux"
        preset="release"
        build_dir="build/linux-Release-eigen${eigen_lane}"
        apt_packages="build-essential cmake ninja-build curl zip unzip tar pkg-config git gfortran jq"
        unsupported_args=()
        ;;
    windows-cross)
        triplet="x64-mingw-static"
        preset="windows-cross-release"
        build_dir="build/windows-cross-Release-eigen${eigen_lane}"
        apt_packages="build-essential cmake ninja-build curl zip unzip tar pkg-config git jq mingw-w64 g++-mingw-w64-x86-64 gcc-mingw-w64-x86-64"
        unsupported_args=(--allow-unsupported)
        ;;
    *)
        echo "Unknown target platform: $target_platform" >&2
        exit 2
        ;;
esac

case "$eigen_lane" in
    3.4)
        baseline="5bf0c55239da398b8c6f450818c9e28d36bf9966"
        eigen_dependency='{"name":"eigen3"}'
        eigen_override='{"name":"eigen3","version":"3.4.1","port-version":1}'
        ;;
    5)
        baseline="6b07d2d37301e9e7c6fcf771536d2ff6585c5912"
        eigen_dependency='{"name":"eigen3","version>=":"5.0.1"}'
        eigen_override='{"name":"eigen3","version":"5.0.1"}'
        ;;
    *)
        echo "Unknown Eigen lane: $eigen_lane" >&2
        exit 2
        ;;
esac

apt-get update
apt-get install -y ${apt_packages}

export VCPKG_ROOT="${BITBUCKET_CLONE_DIR}/vcpkg"
export VCPKG_BUILD_TYPE=release
export VCPKG_OVERLAY_PORTS="${BITBUCKET_CLONE_DIR}/scripts/ci/vcpkg-overlay-ports"

lane_name="${target_platform}-eigen${eigen_lane}"
manifest_dir="${BITBUCKET_CLONE_DIR}/.ci-vcpkg-manifests/${lane_name}"
install_root="${BITBUCKET_CLONE_DIR}/vcpkg_installed/${lane_name}"
binary_cache="${BITBUCKET_CLONE_DIR}/.vcpkg-cache/${lane_name}"

export VCPKG_BINARY_SOURCES="clear;files,${binary_cache},readwrite"

mkdir -p "$manifest_dir" "$install_root" "$binary_cache"

if [ ! -f "$VCPKG_ROOT/bootstrap-vcpkg.sh" ]; then
    rm -rf "$VCPKG_ROOT"
    git clone https://github.com/Microsoft/vcpkg.git "$VCPKG_ROOT"
fi

if [ ! -x "$VCPKG_ROOT/vcpkg" ]; then
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi

jq \
    --arg baseline "$baseline" \
    --argjson eigen_dependency "$eigen_dependency" \
    --argjson eigen_override "$eigen_override" \
    '
    del(."builtin-baseline", .overrides)
    | .dependencies |= map(
        if . == "eigen3" then $eigen_dependency
        elif (type == "object" and .name == "eigen3") then $eigen_dependency
        else .
        end
      )
    | .["builtin-baseline"] = $baseline
    | .overrides = [$eigen_override]
    ' \
    "${BITBUCKET_CLONE_DIR}/vcpkg.json" > "${manifest_dir}/vcpkg.json"

"$VCPKG_ROOT/vcpkg" install \
    --triplet "$triplet" \
    --x-manifest-root="$manifest_dir" \
    --x-install-root="$install_root" \
    --overlay-ports="$VCPKG_OVERLAY_PORTS" \
    "${unsupported_args[@]}" \
    --clean-after-build

cd "${BITBUCKET_CLONE_DIR}/src"
rm -rf "$build_dir"
cmake --preset "$preset" \
    -DVCPKG_MANIFEST_DIR="$manifest_dir" \
    -DVCPKG_INSTALLED_DIR="$install_root" \
    -DVCPKG_OVERLAY_PORTS="$VCPKG_OVERLAY_PORTS" \
    -DEigen3_DIR="${install_root}/${triplet}/share/eigen3" \
    -B "$build_dir"
cmake --build "$build_dir" --parallel 8
