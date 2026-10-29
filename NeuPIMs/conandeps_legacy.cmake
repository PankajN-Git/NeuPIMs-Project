message(STATUS "Conan: Using CMakeDeps conandeps_legacy.cmake aggregator via include()")
message(STATUS "Conan: It is recommended to use explicit find_package() per dependency instead")

find_package(Boost)
find_package(robin_hood)
find_package(spdlog)
find_package(nlohmann_json)

set(CONANDEPS_LEGACY  boost::boost  robin_hood::robin_hood  spdlog::spdlog  nlohmann_json::nlohmann_json )