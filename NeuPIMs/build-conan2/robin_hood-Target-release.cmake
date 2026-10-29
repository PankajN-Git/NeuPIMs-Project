# Avoid multiple calls to find_package to append duplicated properties to the targets
include_guard()########### VARIABLES #######################################################################
#############################################################################################
set(robin-hood-hashing_FRAMEWORKS_FOUND_RELEASE "") # Will be filled later
conan_find_apple_frameworks(robin-hood-hashing_FRAMEWORKS_FOUND_RELEASE "${robin-hood-hashing_FRAMEWORKS_RELEASE}" "${robin-hood-hashing_FRAMEWORK_DIRS_RELEASE}")

set(robin-hood-hashing_LIBRARIES_TARGETS "") # Will be filled later


######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
if(NOT TARGET robin-hood-hashing_DEPS_TARGET)
    add_library(robin-hood-hashing_DEPS_TARGET INTERFACE IMPORTED)
endif()

set_property(TARGET robin-hood-hashing_DEPS_TARGET
             APPEND PROPERTY INTERFACE_LINK_LIBRARIES
             $<$<CONFIG:Release>:${robin-hood-hashing_FRAMEWORKS_FOUND_RELEASE}>
             $<$<CONFIG:Release>:${robin-hood-hashing_SYSTEM_LIBS_RELEASE}>
             $<$<CONFIG:Release>:>)

####### Find the libraries declared in cpp_info.libs, create an IMPORTED target for each one and link the
####### robin-hood-hashing_DEPS_TARGET to all of them
conan_package_library_targets("${robin-hood-hashing_LIBS_RELEASE}"    # libraries
                              "${robin-hood-hashing_LIB_DIRS_RELEASE}" # package_libdir
                              "${robin-hood-hashing_BIN_DIRS_RELEASE}" # package_bindir
                              "${robin-hood-hashing_LIBRARY_TYPE_RELEASE}"
                              "${robin-hood-hashing_IS_HOST_WINDOWS_RELEASE}"
                              robin-hood-hashing_DEPS_TARGET
                              robin-hood-hashing_LIBRARIES_TARGETS  # out_libraries_targets
                              "_RELEASE"
                              "robin-hood-hashing"    # package_name
                              "${robin-hood-hashing_NO_SONAME_MODE_RELEASE}")  # soname

# FIXME: What is the result of this for multi-config? All configs adding themselves to path?
set(CMAKE_MODULE_PATH ${robin-hood-hashing_BUILD_DIRS_RELEASE} ${CMAKE_MODULE_PATH})

########## GLOBAL TARGET PROPERTIES Release ########################################
    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                 $<$<CONFIG:Release>:${robin-hood-hashing_OBJECTS_RELEASE}>
                 $<$<CONFIG:Release>:${robin-hood-hashing_LIBRARIES_TARGETS}>
                 )

    if("${robin-hood-hashing_LIBS_RELEASE}" STREQUAL "")
        # If the package is not declaring any "cpp_info.libs" the package deps, system libs,
        # frameworks etc are not linked to the imported targets and we need to do it to the
        # global target
        set_property(TARGET robin_hood::robin_hood
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     robin-hood-hashing_DEPS_TARGET)
    endif()

    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_LINK_OPTIONS
                 $<$<CONFIG:Release>:${robin-hood-hashing_LINKER_FLAGS_RELEASE}>)
    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                 $<$<CONFIG:Release>:${robin-hood-hashing_INCLUDE_DIRS_RELEASE}>)
    # Necessary to find LINK shared libraries in Linux
    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_LINK_DIRECTORIES
                 $<$<CONFIG:Release>:${robin-hood-hashing_LIB_DIRS_RELEASE}>)
    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS
                 $<$<CONFIG:Release>:${robin-hood-hashing_COMPILE_DEFINITIONS_RELEASE}>)
    set_property(TARGET robin_hood::robin_hood
                 APPEND PROPERTY INTERFACE_COMPILE_OPTIONS
                 $<$<CONFIG:Release>:${robin-hood-hashing_COMPILE_OPTIONS_RELEASE}>)

########## For the modules (FindXXX)
set(robin-hood-hashing_LIBRARIES_RELEASE robin_hood::robin_hood)
