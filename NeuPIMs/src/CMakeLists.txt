CMAKE_MINIMUM_REQUIRED(VERSION 3.15)

set(LIB_NAME "Simulator")

file(GLOB_RECURSE SRC_FILES
    "${CMAKE_SOURCE_DIR}/src/*.h"
    "${CMAKE_SOURCE_DIR}/src/*.cc"
)

find_package(robin_hood REQUIRED)
find_package(spdlog REQUIRED)
find_package(Boost REQUIRED COMPONENTS program_options)
find_package(nlohmann_json REQUIRED)
find_package(fmt REQUIRED)

find_path(RH_INC NAMES robin_hood.h)
find_path(SPD_INC NAMES spdlog/spdlog.h)
find_path(JSON_INC NAMES nlohmann/json.hpp)
find_path(BOOST_INC NAMES boost/program_options.hpp)
find_path(FMT_INC NAMES fmt/core.h)

# Let standard CMake physically locate the compiled binary file
find_library(BOOST_PO_LIB NAMES boost_program_options)

include_directories(${RH_INC} ${SPD_INC} ${JSON_INC} ${BOOST_INC} ${FMT_INC})
add_compile_definitions(SPDLOG_FMT_EXTERNAL FMT_HEADER_ONLY)

add_executable(${LIB_NAME} ${SRC_FILES})
add_library(${LIB_NAME}_lib ${SRC_FILES})

# Inject the found library directly into the linker
target_link_libraries(${LIB_NAME} robin_hood::robin_hood spdlog::spdlog nlohmann_json::nlohmann_json fmt::fmt ${BOOST_PO_LIB})
target_link_libraries(${LIB_NAME}_lib robin_hood::robin_hood spdlog::spdlog nlohmann_json::nlohmann_json fmt::fmt ${BOOST_PO_LIB})
