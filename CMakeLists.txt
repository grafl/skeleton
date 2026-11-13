cmake_minimum_required(VERSION 3.15)

project(skeleton VERSION 0.0.1 LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_executable(skeleton)
target_sources(skeleton PRIVATE src/main.c)
target_include_directories(skeleton PRIVATE include)

set(APR_BUILD_SHARED OFF CACHE BOOL "Build APR shared libraries")
set(APR_BUILD_STATIC ON CACHE BOOL "Build APR static libraries")
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
add_subdirectory(external/apr)

set(EXPAT_BUILD_TOOLS OFF CACHE BOOL "Build Expat tools")
set(EXPAT_BUILD_EXAMPLES OFF CACHE BOOL "Build Expat examples")
set(EXPAT_BUILD_TESTS OFF CACHE BOOL "Build Expat tests")
set(EXPAT_SHARED_LIBS OFF CACHE BOOL "Build Expat shared libraries")
add_subdirectory(external/expat/expat EXCLUDE_FROM_ALL)

set(APR_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/external/apr" CACHE PATH "APR include directory")
# APR-Util requires an existing library path at configure time, even for an in-tree APR target.
set(APR_LIBRARIES "${CMAKE_CURRENT_BINARY_DIR}/apr-util-apr-check.lib"
    CACHE FILEPATH "APR-Util configure-time check path" FORCE
)
file(WRITE "${APR_LIBRARIES}" "")
set(APR_HAS_LDAP OFF CACHE BOOL "Build APR-Util LDAP support")
set(APU_HAVE_ODBC OFF CACHE BOOL "Build APR-Util ODBC support")
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
add_subdirectory(external/apr-util EXCLUDE_FROM_ALL)
file(REMOVE "${APR_LIBRARIES}")

target_include_directories(aprutil-1 PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/external/apr/include"
)
get_target_property(_aprutil_libraries aprutil-1 LINK_LIBRARIES)
list(REMOVE_ITEM _aprutil_libraries "${APR_LIBRARIES}")
set_property(TARGET aprutil-1 PROPERTY LINK_LIBRARIES "${_aprutil_libraries}")
get_target_property(_aprutil_interface_libraries aprutil-1 INTERFACE_LINK_LIBRARIES)
if(_aprutil_interface_libraries)
    list(REMOVE_ITEM _aprutil_interface_libraries "${APR_LIBRARIES}")
    set_property(TARGET aprutil-1 PROPERTY INTERFACE_LINK_LIBRARIES
        "${_aprutil_interface_libraries}"
    )
endif()
target_link_libraries(aprutil-1 apr-1)

target_include_directories(skeleton PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/external/apr-util/include"
    "${CMAKE_CURRENT_BINARY_DIR}/external/apr-util"
)
target_compile_definitions(skeleton PRIVATE APU_DECLARE_STATIC)
target_link_libraries(skeleton PRIVATE aprutil-1)

option(SKELETON_BUILD_HTTPD "Build Apache HTTP Server for local testing" ON)
if(SKELETON_BUILD_HTTPD)
    include(cmake/BuildHttpd.cmake)

    add_library(test1 SHARED src/test1.c)
    add_dependencies(test1 httpd-server)
    include(GenerateExportHeader)
    generate_export_header(test1
        EXPORT_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/include/test1_export.h"
    )
    target_include_directories(test1 PUBLIC
        include
        "${CMAKE_CURRENT_BINARY_DIR}/include"
        "${HTTPD_TEST_ROOT}/include"
    )
    target_compile_definitions(test1 PUBLIC WINNT APR_DECLARE_IMPORT)
    target_link_libraries(test1 PRIVATE "${HTTPD_TEST_ROOT}/lib/libapr-1.lib")
    set_target_properties(test1 PROPERTIES
        PREFIX ""
        LIBRARY_OUTPUT_DIRECTORY "${HTTPD_TEST_ROOT}/bin"
        RUNTIME_OUTPUT_DIRECTORY "${HTTPD_TEST_ROOT}/bin"
    )

    add_library(mod_test MODULE src/mod_test.c)
    add_dependencies(mod_test httpd-server)
    target_include_directories(mod_test PRIVATE "${HTTPD_TEST_ROOT}/include")
    target_compile_definitions(mod_test PRIVATE WINNT APR_DECLARE_IMPORT APU_DECLARE_IMPORT)
    target_link_libraries(mod_test PRIVATE test1 "${HTTPD_TEST_ROOT}/lib/libhttpd.lib")
    set_target_properties(mod_test PROPERTIES
        PREFIX ""
        SUFFIX ".so"
        LIBRARY_OUTPUT_DIRECTORY "${HTTPD_TEST_ROOT}/modules"
        RUNTIME_OUTPUT_DIRECTORY "${HTTPD_TEST_ROOT}/modules"
    )
endif()
