# SPDX-FileCopyrightText: 2017 sudachi Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

# This function downloads a binary library package from our external repo.
# Params:
#   remote_path: path to the file to download, relative to the remote repository root
#   prefix_var: name of a variable which will be set with the path to the extracted contents
function(download_bundled_external remote_path lib_name prefix_var)
    # Sudachi Galaxy LowRAM: FFmpeg Android bundle fallback
    # Download the original arm64 FFmpeg 5.1 bundle from a surviving mirror.
    # Unlike the legacy downloader, fail immediately if the archive is unavailable.
    if(ANDROID AND "${lib_name}" STREQUAL "ffmpeg-android-v5.1.LTS-aarch64")
        set(_sudachi_ffmpeg_prefix "${CMAKE_BINARY_DIR}/externals/${lib_name}")
        if(NOT EXISTS "${_sudachi_ffmpeg_prefix}/lib/libavcodec.so")
            file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/externals")
            set(_sudachi_ffmpeg_archive "${CMAKE_BINARY_DIR}/externals/${lib_name}.tar.xz")
            set(_sudachi_ffmpeg_urls
                "https://gitlab.com/suyu-emu/ext-android-bin/-/raw/main/ffmpeg/${lib_name}.tar.xz"
                "https://git.suyu.dev/suyu/ext-android-bin/raw/branch/main/ffmpeg/${lib_name}.tar.xz")
            set(_sudachi_ffmpeg_ready FALSE)
            foreach(_sudachi_ffmpeg_url IN LISTS _sudachi_ffmpeg_urls)
                message(STATUS "Trying Sudachi arm64 FFmpeg bundle from ${_sudachi_ffmpeg_url}")
                file(DOWNLOAD "${_sudachi_ffmpeg_url}" "${_sudachi_ffmpeg_archive}"
                    STATUS _sudachi_ffmpeg_download_status TLS_VERIFY ON SHOW_PROGRESS)
                list(GET _sudachi_ffmpeg_download_status 0 _sudachi_ffmpeg_download_code)
                if(NOT _sudachi_ffmpeg_download_code EQUAL 0)
                    message(WARNING "FFmpeg download failed: ${_sudachi_ffmpeg_download_status}")
                    continue()
                endif()
                execute_process(
                    COMMAND "${CMAKE_COMMAND}" -E tar xf "${_sudachi_ffmpeg_archive}"
                    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/externals"
                    RESULT_VARIABLE _sudachi_ffmpeg_extract_result
                    ERROR_VARIABLE _sudachi_ffmpeg_extract_error)
                if(_sudachi_ffmpeg_extract_result EQUAL 0 AND
                    EXISTS "${_sudachi_ffmpeg_prefix}/lib/libavcodec.so" AND
                    EXISTS "${_sudachi_ffmpeg_prefix}/lib/libavfilter.so")
                    set(_sudachi_ffmpeg_ready TRUE)
                    break()
                endif()
                message(WARNING "FFmpeg archive invalid/incomplete: ${_sudachi_ffmpeg_extract_error}")
                file(REMOVE_RECURSE "${_sudachi_ffmpeg_prefix}")
            endforeach()
            if(NOT _sudachi_ffmpeg_ready)
                message(FATAL_ERROR "Sudachi Android FFmpeg 5.1 arm64 archive unavailable; cannot link APK")
            endif()
        endif()
        message(STATUS "Sudachi arm64 FFmpeg libraries verified: ${_sudachi_ffmpeg_prefix}")
        if(NOT "${prefix_var}" STREQUAL "")
            set(${prefix_var} "${_sudachi_ffmpeg_prefix}" PARENT_SCOPE)
        endif()
        return()
    endif()

set(package_base_url "https://github.com/sudachi-emu/")
set(package_repo "no_platform")
set(package_extension "no_platform")
if (WIN32)
    set(package_repo "windows-binaries/raw/main/")
    set(package_extension ".7z")
elseif (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(package_repo "linux-binaries/raw/main/")
    set(package_extension ".tar.xz")
elseif (ANDROID)    
    set(package_repo "android-binaries/raw/main/")
    set(package_extension ".tar.xz")
else()
    message(FATAL_ERROR "No package available for this platform")
endif()
set(package_url "${package_base_url}${package_repo}")

set(prefix "${CMAKE_BINARY_DIR}/externals/${lib_name}")
if (NOT EXISTS "${prefix}")
    message(STATUS "Downloading binaries for ${lib_name}...")
    file(DOWNLOAD
        ${package_url}${remote_path}${lib_name}${package_extension}
        "${CMAKE_BINARY_DIR}/externals/${lib_name}${package_extension}" SHOW_PROGRESS)
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${CMAKE_BINARY_DIR}/externals/${lib_name}${package_extension}"
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/externals")
endif()
message(STATUS "Using bundled binaries at ${prefix}")
set(${prefix_var} "${prefix}" PARENT_SCOPE)
endfunction()

function(download_moltenvk_external platform version)
    set(MOLTENVK_DIR "${CMAKE_BINARY_DIR}/externals/MoltenVK")
    set(MOLTENVK_TAR "${CMAKE_BINARY_DIR}/externals/MoltenVK.tar")
    if (NOT EXISTS ${MOLTENVK_DIR})
        if (NOT EXISTS ${MOLTENVK_TAR})
            file(DOWNLOAD https://github.com/KhronosGroup/MoltenVK/releases/download/${version}/MoltenVK-${platform}.tar
                ${MOLTENVK_TAR} SHOW_PROGRESS)
        endif()

        execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf "${MOLTENVK_TAR}"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/externals")
    endif()

    # Add the MoltenVK library path to the prefix so find_library can locate it.
    list(APPEND CMAKE_PREFIX_PATH "${MOLTENVK_DIR}/MoltenVK/dylib/${platform}")
    set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} PARENT_SCOPE)
endfunction()
