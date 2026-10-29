########## MACROS ###########################################################################
#############################################################################################

# Requires CMake > 3.15
if(${CMAKE_VERSION} VERSION_LESS "3.15")
    message(FATAL_ERROR "The 'CMakeDeps' generator only works with CMake >= 3.15")
endif()

if(robin_hood_FIND_QUIETLY)
    set(robin_hood_MESSAGE_MODE VERBOSE)
else()
    set(robin_hood_MESSAGE_MODE STATUS)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/cmakedeps_macros.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/robin_hoodTargets.cmake)
include(CMakeFindDependencyMacro)

check_build_type_defined()

foreach(_DEPENDENCY ${robin-hood-hashing_FIND_DEPENDENCY_NAMES} )
    # Check that we have not already called a find_package with the transitive dependency
    if(NOT ${_DEPENDENCY}_FOUND)
        find_dependency(${_DEPENDENCY} REQUIRED ${${_DEPENDENCY}_FIND_MODE})
    endif()
endforeach()

set(robin_hood_VERSION_STRING "3.11.5")
set(robin_hood_INCLUDE_DIRS ${robin-hood-hashing_INCLUDE_DIRS_RELEASE} )
set(robin_hood_INCLUDE_DIR ${robin-hood-hashing_INCLUDE_DIRS_RELEASE} )
set(robin_hood_LIBRARIES ${robin-hood-hashing_LIBRARIES_RELEASE} )
set(robin_hood_DEFINITIONS ${robin-hood-hashing_DEFINITIONS_RELEASE} )


# Definition of extra CMake variables from cmake_extra_variables


# Only the last installed configuration BUILD_MODULES are included to avoid the collision
foreach(_BUILD_MODULE ${robin-hood-hashing_BUILD_MODULES_PATHS_RELEASE} )
    message(${robin_hood_MESSAGE_MODE} "Conan: Including build module from '${_BUILD_MODULE}'")
    include(${_BUILD_MODULE})
endforeach()


