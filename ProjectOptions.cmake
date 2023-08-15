include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(ad_astra_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(ad_astra_setup_options)
  option(ad_astra_ENABLE_HARDENING "Enable hardening" ON)
  option(ad_astra_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    ad_astra_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    ad_astra_ENABLE_HARDENING
    OFF)

  ad_astra_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR ad_astra_PACKAGING_MAINTAINER_MODE)
    option(ad_astra_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(ad_astra_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(ad_astra_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(ad_astra_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ad_astra_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ad_astra_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(ad_astra_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(ad_astra_ENABLE_PCH "Enable precompiled headers" OFF)
    option(ad_astra_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(ad_astra_ENABLE_IPO "Enable IPO/LTO" ON)
    option(ad_astra_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(ad_astra_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(ad_astra_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(ad_astra_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(ad_astra_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(ad_astra_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(ad_astra_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(ad_astra_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(ad_astra_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(ad_astra_ENABLE_PCH "Enable precompiled headers" OFF)
    option(ad_astra_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      ad_astra_ENABLE_IPO
      ad_astra_WARNINGS_AS_ERRORS
      ad_astra_ENABLE_USER_LINKER
      ad_astra_ENABLE_SANITIZER_ADDRESS
      ad_astra_ENABLE_SANITIZER_LEAK
      ad_astra_ENABLE_SANITIZER_UNDEFINED
      ad_astra_ENABLE_SANITIZER_THREAD
      ad_astra_ENABLE_SANITIZER_MEMORY
      ad_astra_ENABLE_UNITY_BUILD
      ad_astra_ENABLE_CLANG_TIDY
      ad_astra_ENABLE_CPPCHECK
      ad_astra_ENABLE_COVERAGE
      ad_astra_ENABLE_PCH
      ad_astra_ENABLE_CACHE)
  endif()

  ad_astra_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (ad_astra_ENABLE_SANITIZER_ADDRESS OR ad_astra_ENABLE_SANITIZER_THREAD OR ad_astra_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(ad_astra_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(ad_astra_global_options)
  if(ad_astra_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    ad_astra_enable_ipo()
  endif()

  ad_astra_supports_sanitizers()

  if(ad_astra_ENABLE_HARDENING AND ad_astra_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR ad_astra_ENABLE_SANITIZER_UNDEFINED
       OR ad_astra_ENABLE_SANITIZER_ADDRESS
       OR ad_astra_ENABLE_SANITIZER_THREAD
       OR ad_astra_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${ad_astra_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${ad_astra_ENABLE_SANITIZER_UNDEFINED}")
    ad_astra_enable_hardening(ad_astra_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(ad_astra_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(ad_astra_warnings INTERFACE)
  add_library(ad_astra_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  ad_astra_set_project_warnings(
    ad_astra_warnings
    ${ad_astra_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(ad_astra_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(ad_astra_options)
  endif()

  include(cmake/Sanitizers.cmake)
  ad_astra_enable_sanitizers(
    ad_astra_options
    ${ad_astra_ENABLE_SANITIZER_ADDRESS}
    ${ad_astra_ENABLE_SANITIZER_LEAK}
    ${ad_astra_ENABLE_SANITIZER_UNDEFINED}
    ${ad_astra_ENABLE_SANITIZER_THREAD}
    ${ad_astra_ENABLE_SANITIZER_MEMORY})

  set_target_properties(ad_astra_options PROPERTIES UNITY_BUILD ${ad_astra_ENABLE_UNITY_BUILD})

  if(ad_astra_ENABLE_PCH)
    target_precompile_headers(
      ad_astra_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(ad_astra_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    ad_astra_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(ad_astra_ENABLE_CLANG_TIDY)
    ad_astra_enable_clang_tidy(ad_astra_options ${ad_astra_WARNINGS_AS_ERRORS})
  endif()

  if(ad_astra_ENABLE_CPPCHECK)
    ad_astra_enable_cppcheck(${ad_astra_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(ad_astra_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    ad_astra_enable_coverage(ad_astra_options)
  endif()

  if(ad_astra_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(ad_astra_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(ad_astra_ENABLE_HARDENING AND NOT ad_astra_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR ad_astra_ENABLE_SANITIZER_UNDEFINED
       OR ad_astra_ENABLE_SANITIZER_ADDRESS
       OR ad_astra_ENABLE_SANITIZER_THREAD
       OR ad_astra_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    ad_astra_enable_hardening(ad_astra_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
