# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(property LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "property")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Set policy to allow older cmake_minimum_required in subdirectories
# This helps with Firebase SDK compatibility
if(POLICY CMP0000)
  cmake_policy(SET CMP0000 NEW)
endif()

# Set minimum policy version to allow subdirectories with lower CMake versions
# This is needed for Firebase SDK compatibility
if(POLICY CMP0990)
  cmake_policy(SET CMP0990 NEW)
endif()
set(CMAKE_POLICY_DEFAULT_CMP0990 NEW)

# Set CMAKE_POLICY_VERSION_MINIMUM to allow older cmake_minimum_required
# This prevents CMake from erroring on Firebase SDK's old version requirement
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "Minimum CMake policy version")

# Suppress CMake deprecation warnings for compatibility with Firebase SDK
# This allows subdirectories to use older cmake_minimum_required without warnings
# Note: This is an informational warning and does not affect the build
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.10")
  # Suppress deprecation warnings for cmake_minimum_required in subdirectories
  if(POLICY CMP0990)
    cmake_policy(SET CMP0990 NEW)
  endif()
endif()

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Function to fix Firebase C++ SDK CMakeLists.txt compatibility issue
function(fix_firebase_cmake)
  # Check multiple possible locations where Firebase SDK might be extracted
  set(SEARCH_DIRS
    "${CMAKE_BINARY_DIR}"
    "${CMAKE_SOURCE_DIR}/build/windows"
    "${CMAKE_SOURCE_DIR}/build"
    "${CMAKE_CURRENT_SOURCE_DIR}/build/windows"
    "${CMAKE_CURRENT_SOURCE_DIR}/build"
    "${CMAKE_CURRENT_SOURCE_DIR}/../build/windows"
    "${CMAKE_CURRENT_SOURCE_DIR}/../build"
  )
  
  foreach(SEARCH_DIR ${SEARCH_DIRS})
    if(EXISTS "${SEARCH_DIR}")
      # Use GLOB_RECURSE to search all subdirectories for Firebase SDK CMakeLists.txt
      # Search for all possible paths including x64, x86, extracted subdirectories
      file(GLOB_RECURSE FIREBASE_CMAKE_LISTS 
        "${SEARCH_DIR}/*/firebase_cpp_sdk_windows/CMakeLists.txt"
        "${SEARCH_DIR}/*/extracted/firebase_cpp_sdk_windows/CMakeLists.txt"
        "${SEARCH_DIR}/*/*/firebase_cpp_sdk_windows/CMakeLists.txt"
        "${SEARCH_DIR}/*/*/extracted/firebase_cpp_sdk_windows/CMakeLists.txt"
      )
      foreach(FILE ${FIREBASE_CMAKE_LISTS})
        if(EXISTS "${FILE}")
          file(READ "${FILE}" FILE_CONTENT)
          # Check for various patterns: VERSION 3.0 through 3.9, with or without spaces
          # Match patterns like: cmake_minimum_required(VERSION 3.5) or cmake_minimum_required (VERSION 3.5)
          if(FILE_CONTENT MATCHES "cmake_minimum_required[ \t]*\\(VERSION 3\\.[0-9]\\)")
            # Replace any version 3.0-3.9 with 3.10 (preserve original formatting)
            string(REGEX REPLACE 
              "cmake_minimum_required[ \t]*\\(VERSION 3\\.[0-9]\\)" 
              "cmake_minimum_required(VERSION 3.10)" 
              NEW_CONTENT "${FILE_CONTENT}")
            if(NOT "${NEW_CONTENT}" STREQUAL "${FILE_CONTENT}")
              file(WRITE "${FILE}" "${NEW_CONTENT}")
              message(STATUS "Fixed Firebase SDK CMakeLists.txt (updated to 3.10): ${FILE}")
            endif()
          endif()
        endif()
      endforeach()
    endif()
  endforeach()
endfunction()

# Fix Firebase SDK as early as possible (before any subdirectories are processed)
# This runs early to catch SDK files that might already exist from previous builds
fix_firebase_cmake()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Fix Firebase SDK again before plugins are included (pre-emptive fix)
fix_firebase_cmake()

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
# Note: Firebase SDK may be extracted during plugin processing, so we need to
# fix it both before and after plugin inclusion
include(flutter/generated_plugins.cmake)

# Fix Firebase SDK after plugins are included (SDK is extracted during plugin processing)
# This ensures any newly extracted SDK files are also fixed
# Run multiple times to catch files that may be extracted asynchronously
fix_firebase_cmake()
fix_firebase_cmake()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

# Ensure install directories are created
install(CODE "
  file(MAKE_DIRECTORY \"${INSTALL_BUNDLE_DATA_DIR}\")
  file(MAKE_DIRECTORY \"${INSTALL_BUNDLE_LIB_DIR}\")
  " COMPONENT Runtime)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

if(EXISTS "${FLUTTER_ICU_DATA_FILE}")
  install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)
endif()

if(EXISTS "${FLUTTER_LIBRARY}")
  install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

if(PLUGIN_BUNDLED_LIBRARIES)
  foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
    if(EXISTS "${bundled_library}")
      install(FILES "${bundled_library}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)
    endif()
  endforeach()
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
if(EXISTS "${NATIVE_ASSETS_DIR}")
  install(DIRECTORY "${NATIVE_ASSETS_DIR}"
     DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
     COMPONENT Runtime)
endif()

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  if(EXISTS \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
    file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  endif()
  " COMPONENT Runtime)
if(EXISTS "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}")
  install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
endif()

# Install the AOT library on non-Debug builds only.
if(EXISTS "${AOT_LIBRARY}")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    CONFIGURATIONS Profile;Release
    COMPONENT Runtime)
endif()
