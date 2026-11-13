if(NOT TARGET expat)
    message(FATAL_ERROR "The local Expat submodule target is required")
endif()

set(EXPAT_FOUND TRUE)
set(EXPAT_INCLUDE_DIRS
    "${CMAKE_CURRENT_LIST_DIR}/../external/expat/expat/lib"
    "${CMAKE_BINARY_DIR}/external/expat/expat"
)
set(EXPAT_LIBRARIES expat)
