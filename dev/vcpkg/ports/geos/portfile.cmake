set(GEOS_VERSION 3.10.7)

vcpkg_download_distfile(
  ARCHIVE
  URLS
  "https://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2"
  FILENAME
  "geos-${GEOS_VERSION}.tar.bz2"
  SHA512
  22d91894a5c1449a11da5b9f064a77a55383601fd04b4eb7d2d40f0e85e3bb74389b12c437269b40e0286f2e9d6e90d73de89fadc391f696513f57dc066d8df5
)
vcpkg_extract_source_archive_ex(
  OUT_SOURCE_PATH
  SOURCE_PATH
  ARCHIVE
  "${ARCHIVE}"
  REF
  ${GEOS_VERSION}
  PATCHES
  disable-warning-4996.patch
  fix-exported-config.patch
  # The two patches below come from Velox.
  geos-cmakelists.patch)

if(VCPKG_TARGET_IS_MINGW)
  set(_CMAKE_EXTRA_OPTIONS "-DDISABLE_GEOS_INLINE=ON")
else()
  set(_CMAKE_EXTRA_OPTIONS "")
endif()

vcpkg_cmake_configure(
  SOURCE_PATH
  "${SOURCE_PATH}"
  OPTIONS
  -DBUILD_ASTYLE=OFF
  -DBUILD_DOCUMENTATION=OFF
  -DBUILD_GEOSOP=OFF
  -DBUILD_TESTING=OFF
  -DBUILD_BENCHMARKS=OFF
  ${_CMAKE_EXTRA_OPTIONS}
  OPTIONS_DEBUG
  -DCMAKE_DEBUG_POSTFIX=d # Legacy decision, hard coded in depending ports
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/GEOS)
vcpkg_fixup_pkgconfig()

function(geos_add_debug_postfix config_file)
  file(READ "${config_file}" contents)
  string(REGEX REPLACE "(-lgeos(_c)?)d?([^-_d])" "\\1d\\3" fixed_contents
                       "${contents}")
  file(WRITE "${config_file}" "${fixed_contents}")
endfunction()
if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
  if(NOT VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_MINGW)
    file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin")
    file(RENAME "${CURRENT_PACKAGES_DIR}/bin/geos-config"
         "${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin/geos-config")
    file(
      CHMOD
      "${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin/geos-config"
      FILE_PERMISSIONS
      OWNER_READ
      OWNER_WRITE
      OWNER_EXECUTE
      GROUP_READ
      GROUP_EXECUTE
      WORLD_READ
      WORLD_EXECUTE)
  endif()
endif()
if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
  geos_add_debug_postfix("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/geos.pc")
  if(NOT VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_MINGW)
    file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/bin")
    file(RENAME "${CURRENT_PACKAGES_DIR}/debug/bin/geos-config"
         "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/bin/geos-config")
    geos_add_debug_postfix(
      "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/bin/geos-config")
    file(
      CHMOD
      "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/bin/geos-config"
      FILE_PERMISSIONS
      OWNER_READ
      OWNER_WRITE
      OWNER_EXECUTE
      GROUP_READ
      GROUP_EXECUTE
      WORLD_READ
      WORLD_EXECUTE)
  endif()
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static" OR NOT VCPKG_TARGET_IS_WINDOWS)
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin"
       "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

# Handle copyright
configure_file("${SOURCE_PATH}/COPYING"
               "${CURRENT_PACKAGES_DIR}/share/geos/copyright" COPYONLY)

vcpkg_copy_pdbs()
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
