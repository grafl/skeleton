include(ExternalProject)

if(NOT WIN32)
    message(FATAL_ERROR "The bundled httpd CMake build supports Windows only")
endif()

find_program(HTTPD_PERL_EXECUTABLE NAMES perl)
if(NOT HTTPD_PERL_EXECUTABLE)
    find_package(Git REQUIRED)
    get_filename_component(_git_bin "${GIT_EXECUTABLE}" DIRECTORY)
    find_program(HTTPD_PERL_EXECUTABLE NAMES perl
        HINTS "${_git_bin}/../usr/bin"
    )
endif()
if(NOT HTTPD_PERL_EXECUTABLE)
    message(FATAL_ERROR "Perl is required to install httpd; install Perl or Git for Windows")
endif()
get_filename_component(_httpd_perl_bin "${HTTPD_PERL_EXECUTABLE}" DIRECTORY)

set(HTTPD_TEST_ROOT "${CMAKE_BINARY_DIR}/httpd/$<CONFIG>")
set(_httpd_generator_args -G "${CMAKE_GENERATOR}")
if(CMAKE_GENERATOR_PLATFORM)
    list(APPEND _httpd_generator_args -A "${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
    list(APPEND _httpd_generator_args -T "${CMAKE_GENERATOR_TOOLSET}")
endif()

# Separate projects keep httpd's shared APR and legacy target names isolated.
function(_httpd_dependency name source)
    ExternalProject_Add(${name}
        SOURCE_DIR "${PROJECT_SOURCE_DIR}/${source}"
        BINARY_DIR "${CMAKE_BINARY_DIR}/httpd-build/${name}"
        INSTALL_DIR "${CMAKE_BINARY_DIR}/httpd"
        CONFIGURE_COMMAND
            "${CMAKE_COMMAND}" -S <SOURCE_DIR> -B "<BINARY_DIR>/$<CONFIG>"
            ${_httpd_generator_args}
            "-DCMAKE_INSTALL_PREFIX:PATH=${HTTPD_TEST_ROOT}"
            "-DCMAKE_PREFIX_PATH:PATH=${HTTPD_TEST_ROOT}"
            "-DCMAKE_INSTALL_LIBDIR:STRING=lib"
            "-DCMAKE_POLICY_VERSION_MINIMUM:STRING=3.10"
            "-DCMAKE_BUILD_TYPE:STRING=$<CONFIG>"
            ${ARGN}
        BUILD_COMMAND
            "${CMAKE_COMMAND}" --build "<BINARY_DIR>/$<CONFIG>" --config $<CONFIG>
        INSTALL_COMMAND
            "${CMAKE_COMMAND}" --install "<BINARY_DIR>/$<CONFIG>" --config $<CONFIG>
        LOG_CONFIGURE ON
        LOG_BUILD ON
        LOG_INSTALL ON
        LOG_OUTPUT_ON_FAILURE ON
    )
endfunction()

_httpd_dependency(httpd-apr external/apr
    -DAPR_BUILD_SHARED:BOOL=ON
    -DAPR_BUILD_STATIC:BOOL=OFF
    -DAPR_INSTALL_PRIVATE_H:BOOL=ON
    -DAPR_BUILD_TESTAPR:BOOL=OFF
    -DINSTALL_PDB:BOOL=OFF
)

_httpd_dependency(httpd-expat external/expat/expat
    -DEXPAT_SHARED_LIBS:BOOL=OFF
    -DEXPAT_BUILD_TESTS:BOOL=OFF
    -DEXPAT_BUILD_EXAMPLES:BOOL=OFF
    -DEXPAT_BUILD_TOOLS:BOOL=OFF
    -DEXPAT_BUILD_DOCS:BOOL=OFF
)

_httpd_dependency(httpd-apr-util external/apr-util
    "-DAPR_INCLUDE_DIR:PATH=${HTTPD_TEST_ROOT}/include"
    "-DAPR_LIBRARIES:FILEPATH=${HTTPD_TEST_ROOT}/lib/libapr-1.lib"
    -DAPR_HAS_LDAP:BOOL=OFF
    -DAPU_HAVE_ODBC:BOOL=OFF
    -DAPU_HAVE_CRYPTO:BOOL=OFF
    -DAPR_BUILD_TESTAPR:BOOL=OFF
    -DINSTALL_PDB:BOOL=OFF
)
add_dependencies(httpd-apr-util httpd-apr httpd-expat)

_httpd_dependency(httpd-pcre2 external/pcre2
    -DBUILD_SHARED_LIBS:BOOL=OFF
    -DBUILD_STATIC_LIBS:BOOL=ON
    -DPCRE2_BUILD_PCRE2_8:BOOL=ON
    -DPCRE2_BUILD_PCRE2_16:BOOL=OFF
    -DPCRE2_BUILD_PCRE2_32:BOOL=OFF
    -DPCRE2_BUILD_TESTS:BOOL=OFF
    -DPCRE2_BUILD_PCRE2GREP:BOOL=OFF
    -DPCRE2_SUPPORT_JIT:BOOL=OFF
)

set(_httpd_dependencies httpd-apr-util httpd-pcre2)
if(SKELETON_BUILD_OPENSSL)
    list(APPEND _httpd_dependencies openssl)
    # httpd's abs expects applink.c in the installed headers; OpenSSL 4 omits it.
    set(_httpd_openssl_compat "${CMAKE_BINARY_DIR}/httpd-openssl-compat")
    file(MAKE_DIRECTORY "${_httpd_openssl_compat}/openssl")
    configure_file("${PROJECT_SOURCE_DIR}/external/openssl/ms/applink.c"
        "${_httpd_openssl_compat}/openssl/applink.c" COPYONLY)
    set(_httpd_ssl_args
        -DENABLE_SSL:STRING=I
        -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL:BOOL=FALSE
        -DOPENSSL_USE_STATIC_LIBS:BOOL=ON
        "-DOPENSSL_ROOT_DIR:PATH=${_openssl_install}"
        "-DOPENSSL_INCLUDE_DIR:PATH=${_openssl_install}/include"
        "-DOPENSSL_SSL_LIBRARY:FILEPATH=${_openssl_install}/lib/libssl.lib"
        "-DOPENSSL_CRYPTO_LIBRARY:FILEPATH=${_openssl_install}/lib/libcrypto.lib"
        "-DSSL_EAY_DEBUG:FILEPATH=${_openssl_install}/lib/libssl.lib"
        "-DSSL_EAY_RELEASE:FILEPATH=${_openssl_install}/lib/libssl.lib"
        "-DLIB_EAY_DEBUG:FILEPATH=${_openssl_install}/lib/libcrypto.lib"
        "-DLIB_EAY_RELEASE:FILEPATH=${_openssl_install}/lib/libcrypto.lib"
        "-DEXTRA_INCLUDES:PATH=${_httpd_openssl_compat}"
        "-DEXTRA_LIBS:STRING=ws2_32|gdi32|advapi32|crypt32|user32"
    )
else()
    set(_httpd_ssl_args
        -DENABLE_SSL:STRING=O
        -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL:BOOL=TRUE
        -DEXTRA_INCLUDES:PATH=
        -DEXTRA_LIBS:STRING=
    )
endif()

ExternalProject_Add(httpd-server
    SOURCE_DIR "${PROJECT_SOURCE_DIR}/external/httpd"
    BINARY_DIR "${CMAKE_BINARY_DIR}/httpd-build/httpd-server"
    INSTALL_DIR "${CMAKE_BINARY_DIR}/httpd"
    DEPENDS ${_httpd_dependencies}
    CONFIGURE_COMMAND
        "${CMAKE_COMMAND}" -S <SOURCE_DIR> -B "<BINARY_DIR>/$<CONFIG>"
        ${_httpd_generator_args}
        "-DCMAKE_INSTALL_PREFIX:PATH=${HTTPD_TEST_ROOT}"
        "-DCMAKE_PREFIX_PATH:PATH=${HTTPD_TEST_ROOT}"
        "-DCMAKE_BUILD_TYPE:STRING=$<CONFIG>"
        "-DAPR_INCLUDE_DIR:PATH=${HTTPD_TEST_ROOT}/include"
        "-DAPR_LIBRARIES:STRING=${HTTPD_TEST_ROOT}/lib/libapr-1.lib|${HTTPD_TEST_ROOT}/lib/libaprutil-1.lib"
        "-DPCRE_CFLAGS:STRING=-DHAVE_PCRE2 -DPCRE2_STATIC"
        "-DPCRE_INCLUDE_DIR:PATH=${HTTPD_TEST_ROOT}/include"
        "-DPCRE_LIBRARIES:FILEPATH=${HTTPD_TEST_ROOT}/lib/pcre2-8-static$<$<CONFIG:Debug>:d>.lib"
        -DINSTALL_PDB:BOOL=OFF
        -DINSTALL_MANUAL:BOOL=OFF
        ${_httpd_ssl_args}
        -DENABLE_HTTP2:STRING=O
        -DENABLE_PROXY_HTTP2:STRING=O
    LIST_SEPARATOR "|"
    BUILD_COMMAND
        "${CMAKE_COMMAND}" --build "<BINARY_DIR>/$<CONFIG>" --config $<CONFIG>
    INSTALL_COMMAND
        "${CMAKE_COMMAND}"
        "-DHTTPD_BINARY_DIR:PATH=<BINARY_DIR>/$<CONFIG>"
        "-DHTTPD_PERL_BIN:PATH=${_httpd_perl_bin}"
        "-DHTTPD_CONFIG:STRING=$<CONFIG>"
        -P "${PROJECT_SOURCE_DIR}/cmake/InstallHttpd.cmake"
    LOG_CONFIGURE ON
    LOG_BUILD ON
    LOG_INSTALL ON
    LOG_OUTPUT_ON_FAILURE ON
)

ExternalProject_Add_Step(httpd-server prepare-test-runtime
    COMMAND
        "${CMAKE_COMMAND}" "-DHTTPD_TEST_ROOT:PATH=${HTTPD_TEST_ROOT}"
        -P "${PROJECT_SOURCE_DIR}/cmake/PrepareHttpdTest.cmake"
    DEPENDEES install
    DEPENDS
        "${PROJECT_SOURCE_DIR}/cmake/PrepareHttpdTest.cmake"
        "${PROJECT_SOURCE_DIR}/cmake/httpd-test.conf.in"
        "${PROJECT_SOURCE_DIR}/cmake/httpd-test-ssl.conf.in"
        "${PROJECT_SOURCE_DIR}/cmake/httpd-test-index.html"
)
