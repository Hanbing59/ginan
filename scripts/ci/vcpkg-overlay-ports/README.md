# libaec vcpkg overlay port

This directory provides a project-specific vcpkg overlay port for
libaec 1.1.3.

The overlay is used by the CI compatibility build
`../compile_vcpkg_eigen_matrix.sh` and replaces the corresponding
libaec port from the normal vcpkg registry.

## Why this overlay exists

The upstream libaec 1.1.3 CMake integration does not work correctly
for the way this project uses libaec through vcpkg.

The overlay applies two patches:

- `static-shared.patch`
  - Makes the default static/shared library selection follow
    `BUILD_SHARED_LIBS` when `libaec_USE_STATIC_LIBS` is not explicitly
    specified.
  - Installs only the library variant selected by `BUILD_SHARED_LIBS`
    instead of installing both static and shared variants.

- `cmake-config.patch`
  - Improves CMake library discovery.
  - Uses the CMake-generated export targets instead of manually
    creating imported targets in `libaec-config.cmake`.
  - Exports the public targets as `libaec::aec` and `libaec::sz`.

## Usage

The overlay is passed to vcpkg with:

    --overlay-ports=<repository>/scripts/ci/vcpkg-overlay-ports

The resulting package can be used from CMake as:

    find_package(libaec CONFIG REQUIRED)

    target_link_libraries(main PRIVATE libaec::aec)

or:

    target_link_libraries(main PRIVATE libaec::sz)

## Version

This overlay is based on upstream libaec:

    version: 1.1.3

The SHA512 checksum of the downloaded source archive is pinned in
`portfile.cmake`.

## CI usage

The overlay is currently referenced by
`scripts/ci/compile_vcpkg_eigen_matrix.sh`.

That script was originally designed for a Bitbucket Pipelines
environment, but the overlay itself is not Bitbucket-specific.

If the compatibility build is migrated to GitHub Actions, the overlay
can be used unchanged by passing its path through
`--overlay-ports` or `VCPKG_OVERLAY_PORTS`.

## When can this overlay be removed?

Before removing this overlay, verify that the upstream vcpkg libaec
port provides all of the following for the project's required
configuration:

1. Correct static/shared library selection.
2. Correct installation of the selected library variant.
3. Working CMake package configuration.
4. The expected targets:
   `libaec::aec` and `libaec::sz`.

If the upstream vcpkg port has incorporated equivalent fixes, this
overlay may no longer be necessary.