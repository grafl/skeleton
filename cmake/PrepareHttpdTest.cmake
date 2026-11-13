if(NOT DEFINED HTTPD_TEST_ROOT)
    message(FATAL_ERROR "HTTPD_TEST_ROOT is required")
endif()

file(MAKE_DIRECTORY
    "${HTTPD_TEST_ROOT}/conf"
    "${HTTPD_TEST_ROOT}/logs"
    "${HTTPD_TEST_ROOT}/test-htdocs"
)
configure_file("${CMAKE_CURRENT_LIST_DIR}/httpd-test.conf.in"
    "${HTTPD_TEST_ROOT}/conf/test-httpd.conf" @ONLY
)
configure_file("${CMAKE_CURRENT_LIST_DIR}/httpd-test-index.html"
    "${HTTPD_TEST_ROOT}/test-htdocs/index.html" COPYONLY
)
