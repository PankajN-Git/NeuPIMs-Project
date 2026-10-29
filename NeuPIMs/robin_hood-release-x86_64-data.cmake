########### AGGREGATED COMPONENTS AND DEPENDENCIES FOR THE MULTI CONFIG #####################
#############################################################################################

set(robin-hood-hashing_COMPONENT_NAMES "")
if(DEFINED robin-hood-hashing_FIND_DEPENDENCY_NAMES)
  list(APPEND robin-hood-hashing_FIND_DEPENDENCY_NAMES )
  list(REMOVE_DUPLICATES robin-hood-hashing_FIND_DEPENDENCY_NAMES)
else()
  set(robin-hood-hashing_FIND_DEPENDENCY_NAMES )
endif()

########### VARIABLES #######################################################################
#############################################################################################
set(robin-hood-hashing_PACKAGE_FOLDER_RELEASE "/home/pc1/.conan2/p/robin822af90d9529b/p")
set(robin-hood-hashing_BUILD_MODULES_PATHS_RELEASE )


set(robin-hood-hashing_INCLUDE_DIRS_RELEASE "${robin-hood-hashing_PACKAGE_FOLDER_RELEASE}/include")
set(robin-hood-hashing_RES_DIRS_RELEASE )
set(robin-hood-hashing_DEFINITIONS_RELEASE )
set(robin-hood-hashing_SHARED_LINK_FLAGS_RELEASE )
set(robin-hood-hashing_EXE_LINK_FLAGS_RELEASE )
set(robin-hood-hashing_OBJECTS_RELEASE )
set(robin-hood-hashing_COMPILE_DEFINITIONS_RELEASE )
set(robin-hood-hashing_COMPILE_OPTIONS_C_RELEASE )
set(robin-hood-hashing_COMPILE_OPTIONS_CXX_RELEASE )
set(robin-hood-hashing_LIB_DIRS_RELEASE )
set(robin-hood-hashing_BIN_DIRS_RELEASE )
set(robin-hood-hashing_LIBRARY_TYPE_RELEASE UNKNOWN)
set(robin-hood-hashing_IS_HOST_WINDOWS_RELEASE 0)
set(robin-hood-hashing_LIBS_RELEASE )
set(robin-hood-hashing_SYSTEM_LIBS_RELEASE )
set(robin-hood-hashing_FRAMEWORK_DIRS_RELEASE )
set(robin-hood-hashing_FRAMEWORKS_RELEASE )
set(robin-hood-hashing_BUILD_DIRS_RELEASE )
set(robin-hood-hashing_NO_SONAME_MODE_RELEASE FALSE)


# COMPOUND VARIABLES
set(robin-hood-hashing_COMPILE_OPTIONS_RELEASE)
if (NOT "${robin-hood-hashing_COMPILE_OPTIONS_CXX_RELEASE}" STREQUAL "")
    list(APPEND robin-hood-hashing_COMPILE_OPTIONS_RELEASE
        "$<$<COMPILE_LANGUAGE:CXX>:${robin-hood-hashing_COMPILE_OPTIONS_CXX_RELEASE}>")
endif ()
if (NOT "${robin-hood-hashing_COMPILE_OPTIONS_C_RELEASE}" STREQUAL "")
    list(APPEND robin-hood-hashing_COMPILE_OPTIONS_RELEASE
        "$<$<COMPILE_LANGUAGE:C>:${robin-hood-hashing_COMPILE_OPTIONS_C_RELEASE}>")
endif ()
set(robin-hood-hashing_LINKER_FLAGS_RELEASE)
if (NOT "${robin-hood-hashing_SHARED_LINK_FLAGS_RELEASE}" STREQUAL "")
    list(APPEND robin-hood-hashing_LINKER_FLAGS_RELEASE
        "$<$<OR:$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>,$<STREQUAL:$<TARGET_PROPERTY:TYPE>,MODULE_LIBRARY>>:${robin-hood-hashing_SHARED_LINK_FLAGS_RELEASE}>")
endif ()
if (NOT "${robin-hood-hashing_EXE_LINK_FLAGS_RELEASE}" STREQUAL "")
    list(APPEND robin-hood-hashing_LINKER_FLAGS_RELEASE
        "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${robin-hood-hashing_EXE_LINK_FLAGS_RELEASE}>")
endif ()


set(robin-hood-hashing_COMPONENTS_RELEASE )