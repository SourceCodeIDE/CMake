#.rst:
# FindFLEX
# --------
#
# Find flex executable and provides a macro to generate custom build rules
#
#
#
# The module defines the following variables:
#
# ::
#
#   FLEX_FOUND - true is flex executable is found
#   FLEX_EXECUTABLE - the path to the flex executable
#   FLEX_VERSION - the version of flex
#   FLEX_LIBRARIES - The flex libraries
#   FLEX_INCLUDE_DIRS - The path to the flex headers
#
#
#
# The minimum required version of flex can be specified using the
# standard syntax, e.g.  find_package(FLEX 2.5.13)
#
#
#
# If flex is found on the system, the module provides the macro:
#
# ::
#
#   FLEX_TARGET(Name FlexInput FlexOutput
#               [COMPILE_FLAGS <string>]
#               [DEFINES_FILE <string>]
#               )
#
# which creates a custom command to generate the <FlexOutput> file from
# the <FlexInput> file.  If COMPILE_FLAGS option is specified, the next
# parameter is added to the flex command line. If flex is configured to
# output a header file, the DEFINES_FILE option may be used to specify its
# name. Name is an alias used to get details of this custom command.
# Indeed the macro defines the following variables:
#
# ::
#
#   FLEX_${Name}_DEFINED - true is the macro ran successfully
#   FLEX_${Name}_OUTPUTS - the source file generated by the custom rule, an
#   alias for FlexOutput
#   FLEX_${Name}_INPUT - the flex source file, an alias for ${FlexInput}
#   FLEX_${Name}_OUTPUT_HEADER - the header flex output, if any.
#
#
#
# Flex scanners oftenly use tokens defined by Bison: the code generated
# by Flex depends of the header generated by Bison.  This module also
# defines a macro:
#
# ::
#
#   ADD_FLEX_BISON_DEPENDENCY(FlexTarget BisonTarget)
#
# which adds the required dependency between a scanner and a parser
# where <FlexTarget> and <BisonTarget> are the first parameters of
# respectively FLEX_TARGET and BISON_TARGET macros.
#
# ::
#
#   ====================================================================
#   Example:
#
#
#
# ::
#
#    find_package(BISON)
#    find_package(FLEX)
#
#
#
# ::
#
#    BISON_TARGET(MyParser parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.cpp)
#    FLEX_TARGET(MyScanner lexer.l  ${CMAKE_CURRENT_BINARY_DIR}/lexer.cpp)
#    ADD_FLEX_BISON_DEPENDENCY(MyScanner MyParser)
#
#
#
# ::
#
#    include_directories(${CMAKE_CURRENT_BINARY_DIR})
#    add_executable(Foo
#       Foo.cc
#       ${BISON_MyParser_OUTPUTS}
#       ${FLEX_MyScanner_OUTPUTS}
#    )
#   ====================================================================

#=============================================================================
# Copyright 2009 Kitware, Inc.
# Copyright 2006 Tristan Carel
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

find_program(FLEX_EXECUTABLE NAMES flex win_flex DOC "path to the flex executable")
mark_as_advanced(FLEX_EXECUTABLE)

find_library(FL_LIBRARY NAMES fl
  DOC "Path to the fl library")

find_path(FLEX_INCLUDE_DIR FlexLexer.h
  DOC "Path to the flex headers")

mark_as_advanced(FL_LIBRARY FLEX_INCLUDE_DIR)

include(${CMAKE_CURRENT_LIST_DIR}/CMakeParseArguments.cmake)

set(FLEX_INCLUDE_DIRS ${FLEX_INCLUDE_DIR})
set(FLEX_LIBRARIES ${FL_LIBRARY})

if(FLEX_EXECUTABLE)

  execute_process(COMMAND ${FLEX_EXECUTABLE} --version
    OUTPUT_VARIABLE FLEX_version_output
    ERROR_VARIABLE FLEX_version_error
    RESULT_VARIABLE FLEX_version_result
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT ${FLEX_version_result} EQUAL 0)
    if(FLEX_FIND_REQUIRED)
      message(SEND_ERROR "Command \"${FLEX_EXECUTABLE} --version\" failed with output:\n${FLEX_version_output}\n${FLEX_version_error}")
    else()
      message("Command \"${FLEX_EXECUTABLE} --version\" failed with output:\n${FLEX_version_output}\n${FLEX_version_error}\nFLEX_VERSION will not be available")
    endif()
  else()
    # older versions of flex printed "/full/path/to/executable version X.Y"
    # newer versions use "basename(executable) X.Y"
    get_filename_component(FLEX_EXE_NAME_WE "${FLEX_EXECUTABLE}" NAME_WE)
    get_filename_component(FLEX_EXE_EXT "${FLEX_EXECUTABLE}" EXT)
    string(REGEX REPLACE "^.*${FLEX_EXE_NAME_WE}(${FLEX_EXE_EXT})?\"? (version )?([0-9]+[^ ]*)( .*)?$" "\\3"
      FLEX_VERSION "${FLEX_version_output}")
    unset(FLEX_EXE_EXT)
    unset(FLEX_EXE_NAME_WE)
  endif()

  #============================================================
  # FLEX_TARGET (public macro)
  #============================================================
  #
  macro(FLEX_TARGET Name Input Output)
    set(FLEX_TARGET_outputs "${Output}")
    set(FLEX_EXECUTABLE_opts "")

    set(FLEX_TARGET_PARAM_OPTIONS)
    set(FLEX_TARGET_PARAM_ONE_VALUE_KEYWORDS
      COMPILE_FLAGS
      DEFINES_FILE
      )
    set(FLEX_TARGET_PARAM_MULTI_VALUE_KEYWORDS)

    cmake_parse_arguments(
      FLEX_TARGET_ARG
      "${FLEX_TARGET_PARAM_OPTIONS}"
      "${FLEX_TARGET_PARAM_ONE_VALUE_KEYWORDS}"
      "${FLEX_TARGET_MULTI_VALUE_KEYWORDS}"
      ${ARGN}
      )

    set(FLEX_TARGET_usage "FLEX_TARGET(<Name> <Input> <Output> [COMPILE_FLAGS <string>] [DEFINES_FILE <string>]")

    if(NOT "${FLEX_TARGET_ARG_UNPARSED_ARGUMENTS}" STREQUAL "")
      message(SEND_ERROR ${FLEX_TARGET_usage})
    else()
      if(NOT "${FLEX_TARGET_ARG_COMPILE_FLAGS}" STREQUAL "")
        set(FLEX_EXECUTABLE_opts "${FLEX_TARGET_ARG_COMPILE_FLAGS}")
        separate_arguments(FLEX_EXECUTABLE_opts)
      endif()
      if(NOT "${FLEX_TARGET_ARG_DEFINES_FILE}" STREQUAL "")
        list(APPEND FLEX_TARGET_outputs "${FLEX_TARGET_ARG_DEFINES_FILE}")
        list(APPEND FLEX_EXECUTABLE_opts --header-file=${FLEX_TARGET_ARG_DEFINES_FILE})
      endif()

      add_custom_command(OUTPUT ${FLEX_TARGET_outputs}
        COMMAND ${FLEX_EXECUTABLE} ${FLEX_EXECUTABLE_opts} -o${Output} ${Input}
        VERBATIM
        DEPENDS ${Input}
        COMMENT "[FLEX][${Name}] Building scanner with flex ${FLEX_VERSION}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

      set(FLEX_${Name}_DEFINED TRUE)
      set(FLEX_${Name}_OUTPUTS ${Output})
      set(FLEX_${Name}_INPUT ${Input})
      set(FLEX_${Name}_COMPILE_FLAGS ${FLEX_EXECUTABLE_opts})
      if("${FLEX_TARGET_ARG_DEFINES_FILE}" STREQUAL "")
        set(FLEX_${Name}_OUTPUT_HEADER "")
      else()
        set(FLEX_${Name}_OUTPUT_HEADER ${FLEX_TARGET_ARG_DEFINES_FILE})
      endif()
    endif()
  endmacro()
  #============================================================


  #============================================================
  # ADD_FLEX_BISON_DEPENDENCY (public macro)
  #============================================================
  #
  macro(ADD_FLEX_BISON_DEPENDENCY FlexTarget BisonTarget)

    if(NOT FLEX_${FlexTarget}_OUTPUTS)
      message(SEND_ERROR "Flex target `${FlexTarget}' does not exist.")
    endif()

    if(NOT BISON_${BisonTarget}_OUTPUT_HEADER)
      message(SEND_ERROR "Bison target `${BisonTarget}' does not exist.")
    endif()

    set_source_files_properties(${FLEX_${FlexTarget}_OUTPUTS}
      PROPERTIES OBJECT_DEPENDS ${BISON_${BisonTarget}_OUTPUT_HEADER})
  endmacro()
  #============================================================

endif()

include(${CMAKE_CURRENT_LIST_DIR}/FindPackageHandleStandardArgs.cmake)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(FLEX REQUIRED_VARS FLEX_EXECUTABLE
                                       VERSION_VAR FLEX_VERSION)

# FindFLEX.cmake ends here
