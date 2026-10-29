# Load the debug and release variables
file(GLOB DATA_FILES "${CMAKE_CURRENT_LIST_DIR}/robin_hood-*-data.cmake")

foreach(f ${DATA_FILES})
    include(${f})
endforeach()

# Create the targets for all the components
foreach(_COMPONENT ${robin-hood-hashing_COMPONENT_NAMES} )
    if(NOT TARGET ${_COMPONENT})
        add_library(${_COMPONENT} INTERFACE IMPORTED)
        message(${robin_hood_MESSAGE_MODE} "Conan: Component target declared '${_COMPONENT}'")
    endif()
endforeach()

if(NOT TARGET robin_hood::robin_hood)
    add_library(robin_hood::robin_hood INTERFACE IMPORTED)
    message(${robin_hood_MESSAGE_MODE} "Conan: Target declared 'robin_hood::robin_hood'")
endif()
# Load the debug and release library finders
file(GLOB CONFIG_FILES "${CMAKE_CURRENT_LIST_DIR}/robin_hood-Target-*.cmake")

foreach(f ${CONFIG_FILES})
    include(${f})
endforeach()