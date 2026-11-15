include(ExternalProject)

if(NOT WIN32 OR NOT MSVC)
    message(FATAL_ERROR "The OpenSSL integration currently requires Windows and MSVC")
endif()

find_package(Git REQUIRED)
execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${PROJECT_SOURCE_DIR}/external/openssl"
        rev-parse --verify HEAD
    OUTPUT_VARIABLE _openssl_commit
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _openssl_git_result
)
if(NOT _openssl_git_result STREQUAL "0")
    message(FATAL_ERROR "Cannot determine the OpenSSL submodule revision")
endif()
execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${PROJECT_SOURCE_DIR}/external/openssl"
        rev-parse --absolute-git-dir
    OUTPUT_VARIABLE _openssl_git_dir
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _openssl_git_result
)
if(NOT _openssl_git_result STREQUAL "0")
    message(FATAL_ERROR "Cannot locate the OpenSSL submodule Git directory")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_openssl_git_dir}/HEAD")
execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${PROJECT_SOURCE_DIR}/external/openssl"
        symbolic-ref -q HEAD
    OUTPUT_VARIABLE _openssl_ref
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _openssl_ref_result
)
if(_openssl_ref_result STREQUAL "0")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_openssl_git_dir}/${_openssl_ref}" "${_openssl_git_dir}/packed-refs")
endif()
string(SUBSTRING "${_openssl_commit}" 0 12 _openssl_revision)

if(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "x64")
    set(_openssl_target VC-WIN64A)
    set(_openssl_vcvars x64)
elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "X86")
    set(_openssl_target VC-WIN32)
    set(_openssl_vcvars x86)
elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID STREQUAL "ARM64")
    set(_openssl_target VC-WIN64-ARM)
    set(_openssl_vcvars x64_arm64)
else()
    message(FATAL_ERROR "Unsupported OpenSSL MSVC architecture: ${CMAKE_C_COMPILER_ARCHITECTURE_ID}")
endif()

set(OPENSSL_PERL_EXECUTABLE "" CACHE FILEPATH "Native Windows Perl executable for building OpenSSL")
if(NOT OPENSSL_PERL_EXECUTABLE)
    find_program(_openssl_perl NAMES perl HINTS "C:/Strawberry/perl/bin")
    if(_openssl_perl)
        set(OPENSSL_PERL_EXECUTABLE "${_openssl_perl}" CACHE FILEPATH
            "Native Windows Perl executable for building OpenSSL" FORCE)
    endif()
endif()
if(NOT OPENSSL_PERL_EXECUTABLE OR NOT EXISTS "${OPENSSL_PERL_EXECUTABLE}")
    message(FATAL_ERROR
        "OpenSSL requires native Windows Perl (for example Strawberry Perl). "
        "Set OPENSSL_PERL_EXECUTABLE or configure with SKELETON_BUILD_OPENSSL=OFF.")
endif()
execute_process(
    COMMAND "${OPENSSL_PERL_EXECUTABLE}" -e "require IPC::Cmd; exit($^O eq 'MSWin32' ? 0 : 1)"
    RESULT_VARIABLE _openssl_perl_result
    ERROR_VARIABLE _openssl_perl_error
)
if(NOT _openssl_perl_result STREQUAL "0")
    message(FATAL_ERROR
        "OpenSSL requires native Windows Perl with its core modules, not MSYS/Cygwin Perl: "
        "${OPENSSL_PERL_EXECUTABLE}\n${_openssl_perl_error}")
endif()

set(_openssl_vcvarsall "${CMAKE_GENERATOR_INSTANCE}/VC/Auxiliary/Build/vcvarsall.bat")
if(NOT EXISTS "${_openssl_vcvarsall}")
    message(FATAL_ERROR
        "Cannot locate Visual Studio vcvarsall.bat; configure with a Visual Studio generator.")
endif()

get_filename_component(_openssl_perl_bin "${OPENSSL_PERL_EXECUTABLE}" DIRECTORY)
set(_openssl_install_root "${CMAKE_BINARY_DIR}/openssl/${_openssl_revision}")
set(_openssl_install "${_openssl_install_root}/$<CONFIG>")
set(_openssl_build "${CMAKE_BINARY_DIR}/openssl-build/${_openssl_revision}/$<CONFIG>")
set(_openssl_script "${_openssl_build}/openssl-build.cmd")

file(GENERATE OUTPUT "${_openssl_script}" CONTENT
"@echo off
setlocal
set \"PATH=${_openssl_perl_bin};%ProgramFiles(x86)%\\Microsoft Visual Studio\\Installer;%PATH%\"
call \"${_openssl_vcvarsall}\" ${_openssl_vcvars} >nul
if errorlevel 1 exit /b 1
if \"%~1\"==\"configure\" goto configure
if \"%~1\"==\"build\" goto build
if \"%~1\"==\"install\" goto install
echo Unknown OpenSSL build step: %~1 >&2
exit /b 1
:configure
\"${OPENSSL_PERL_EXECUTABLE}\" \"${PROJECT_SOURCE_DIR}/external/openssl/Configure\" ${_openssl_target} $<IF:$<CONFIG:Debug>,--debug,--release> no-asm no-shared no-tests --prefix=\"${_openssl_install}\" --openssldir=\"${_openssl_install}/ssl\" --libdir=lib
exit /b %errorlevel%
:build
nmake /nologo build_libs
exit /b %errorlevel%
:install
nmake /nologo install_dev
exit /b %errorlevel%
")

ExternalProject_Add(openssl
    SOURCE_DIR "${PROJECT_SOURCE_DIR}/external/openssl"
    BINARY_DIR "${CMAKE_BINARY_DIR}/openssl-build/${_openssl_revision}"
    CONFIGURE_COMMAND "${CMAKE_COMMAND}" -E chdir "${_openssl_build}"
        cmd /d /c "${_openssl_script}" configure
    BUILD_COMMAND "${CMAKE_COMMAND}" -E chdir "${_openssl_build}"
        cmd /d /c "${_openssl_script}" build
    INSTALL_COMMAND "${CMAKE_COMMAND}" -E chdir "${_openssl_build}"
        cmd /d /c "${_openssl_script}" install
    BUILD_ALWAYS ON
    BUILD_BYPRODUCTS
        "${_openssl_install}/lib/libcrypto.lib"
        "${_openssl_install}/lib/libssl.lib"
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_INSTALL ON
    LOG_OUTPUT_ON_FAILURE ON
)

if(CMAKE_CONFIGURATION_TYPES)
    set(_openssl_configs ${CMAKE_CONFIGURATION_TYPES})
elseif(CMAKE_BUILD_TYPE)
    set(_openssl_configs "${CMAKE_BUILD_TYPE}")
else()
    set(_openssl_configs NOCONFIG)
endif()

add_library(OpenSSL::Crypto STATIC IMPORTED GLOBAL)
set_target_properties(OpenSSL::Crypto PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_openssl_install}/include"
    INTERFACE_LINK_LIBRARIES "ws2_32;gdi32;advapi32;crypt32;user32"
)
add_dependencies(OpenSSL::Crypto openssl)

add_library(OpenSSL::SSL STATIC IMPORTED GLOBAL)
set_target_properties(OpenSSL::SSL PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_openssl_install}/include"
    INTERFACE_LINK_LIBRARIES OpenSSL::Crypto
)
add_dependencies(OpenSSL::SSL openssl)

foreach(_openssl_config IN LISTS _openssl_configs)
    if(_openssl_config STREQUAL "NOCONFIG")
        set(_openssl_config_dir "${_openssl_install_root}")
    else()
        set(_openssl_config_dir "${_openssl_install_root}/${_openssl_config}")
    endif()
    file(MAKE_DIRECTORY "${_openssl_config_dir}/include")
    string(TOUPPER "${_openssl_config}" _openssl_config_upper)
    set_property(TARGET OpenSSL::Crypto APPEND PROPERTY IMPORTED_CONFIGURATIONS "${_openssl_config}")
    set_property(TARGET OpenSSL::SSL APPEND PROPERTY IMPORTED_CONFIGURATIONS "${_openssl_config}")
    set_target_properties(OpenSSL::Crypto PROPERTIES
        "IMPORTED_LOCATION_${_openssl_config_upper}" "${_openssl_config_dir}/lib/libcrypto.lib")
    set_target_properties(OpenSSL::SSL PROPERTIES
        "IMPORTED_LOCATION_${_openssl_config_upper}" "${_openssl_config_dir}/lib/libssl.lib")
endforeach()
