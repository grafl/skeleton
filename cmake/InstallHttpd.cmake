set(ENV{PATH} "${HTTPD_PERL_BIN};$ENV{PATH}")
execute_process(
    COMMAND "${CMAKE_COMMAND}" --install "${HTTPD_BINARY_DIR}" --config "${HTTPD_CONFIG}"
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "httpd installation failed: ${result}")
endif()
