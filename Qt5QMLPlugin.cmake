include(CMakeParseArguments)

# Set the current directory where this Qt5QMLPlugin.cmake is located
set(__qml_plugin_current_dir ${CMAKE_CURRENT_LIST_DIR} CACHE STRING "Set for Qt5QMLPlugin")

# Control flag to disable generating typeinfo files (if needed)
set(__qml_plugin_no_generate_typeinfo OFF)

# Control flag to disable exposing sources as public (if needed)
set(__qml_plugin_no_public_sources OFF)

# Find Qt5 Core component - required for all operations
find_package(Qt5 REQUIRED COMPONENTS Core)

# Ensure AutoMocHelper is built once
if(NOT TARGET AutoMocHelper)
    # Create the AutoMocHelper executable for generating moc files
    add_executable(AutoMocHelper ${__qml_plugin_current_dir}/automoc_helper.cpp)
    set_target_properties(AutoMocHelper PROPERTIES
        OUTPUT_NAME "AutoMocHelper"  # Set the output name for the helper executable
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}  # Set output directory for the helper
    )
endif()

### Function: FindQmlPluginDump
# Purpose: Locate the qmlplugindump binary which is used for generating QML plugin metadata
function(FindQmlPluginDump)
    # Call FindQtBinDir to find Qt's binary directory
    FindQtBinDir()

    # Set the path to qmlplugindump binary and propagate it
    set(QMLPLUGINDUMP_BIN ${QT_BIN_DIR}/qmlplugindump PARENT_SCOPE)
endfunction()

### Function: FindQtRootDir
# Purpose: Determine the root directory of Qt installation by querying qmake
function(FindQtRootDir)
    # If QT_QMAKE_EXECUTABLE is not set, get it from Qt5::qmake target
    if(NOT QT_QMAKE_EXECUTABLE)
        get_target_property (QT_QMAKE_EXECUTABLE Qt5::qmake IMPORTED_LOCATION)
    endif()
    
    # Execute qmake to find the QT_INSTALL_ARCHDATA path
    execute_process(
            COMMAND ${QT_QMAKE_EXECUTABLE} -query QT_INSTALL_ARCHDATA
            OUTPUT_VARIABLE __QT_ROOT_DIR
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    
    # If the query returns empty, default to a calculated path relative to Qt5_DIR
    if(__QT_ROOT_DIR STREQUAL "")
        cmake_path(SET __QT_ROOT_DIR NORMALIZE ${Qt5_DIR}/../../../)
    endif()
    
    # Propagate the found Qt root directory
    set(QT_ROOT_DIR ${__QT_ROOT_DIR} PARENT_SCOPE)
endfunction()

### Function: FindQtBinDir
# Purpose: Locate the Qt binary directory based on the root directory
function(FindQtBinDir)
    # Call FindQtRootDir to get Qt's root directory
    FindQtRootDir()
    
    # Set the binary directory path and propagate it
    set(QT_BIN_DIR ${QT_ROOT_DIR}/bin PARENT_SCOPE)
endfunction()

### Function: FindQmlTypeRegistrar
# Purpose: Locate the qmltyperegistrar binary used for generating QML type registration files
function(FindQmlTypeRegistrar)
    # Call FindQtBinDir to get Qt's binary directory
    FindQtBinDir()

    # Set the path to qmltyperegistrar and propagate it
    set(QMLTYPEREGISTRAR_BIN ${QT_BIN_DIR}/qmltyperegistrar PARENT_SCOPE)
endfunction()

### Function: FindQtInstallQml
# Purpose: Locate the directory where QML plugins should be installed
function(FindQtInstallQml)
    # Call FindQtRootDir to get Qt's root directory
    FindQtRootDir()
    
    # Set the QML installation directory path and propagate it
    set(QT_QML_INSTALL_DIR ${QT_ROOT_DIR}/qml PARENT_SCOPE)
endfunction()

### Function: qt5_add_resources_plus
# Purpose: Extended version of qt5_add_resources to handle additional resource configurations
function(qt5_add_resources_plus QRC_FILES RESOURCE_NAME)
    # Define options for parsing arguments
    set(options)
    set(oneValueArgs PREFIX OUTPUT_TARGETS)
    set(multiValueArgs BIG_RESOURCES FILES OPTIONS)
    
    # Parse input arguments
    cmake_parse_arguments(__RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if(NOT TARGET ${QRC_FILES})
        set(__is_qrc_files TRUE)
    endif()
    set(__other_rcc_files ${__RCC_UNPARSED_ARGUMENTS})
    # Handle output targets if not provided
    if(NOT __RCC_OUTPUT_TARGETS)
        set(__RCC_OUTPUT_TARGETS "${RESOURCE_NAME}")
    endif()
    
    # Set default prefix for resources
    if(NOT __RCC_PREFIX)
        set(__RCC_PREFIX "/")
    endif()
    
    # Handle regular resources
    if(__RCC_FILES)
        set(__qml_plugin_qrc_prefix ${__RCC_PREFIX})
        __generate_qrc_file(
            OUTPUT_NAME ${__RCC_OUTPUT_TARGETS}
            OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            FILES ${__RCC_FILES}
        )
        list(APPEND __other_rcc_files ${CMAKE_CURRENT_BINARY_DIR}/${__RCC_OUTPUT_TARGETS}.qrc)
    else()
        list(APPEND __other_rcc_files ${RESOURCE_NAME})
    endif()
    
    # Handle big resources (if any)
    if(__RCC_BIG_RESOURCES)
        set(__qml_plugin_qrc_prefix ${__RCC_PREFIX})
        __generate_qrc_file(
            OUTPUT_NAME ${__RCC_OUTPUT_TARGETS}_big
            OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            FILES ${__RCC_BIG_RESOURCES}
        )
        if(__RCC_OPTION)
            qt5_add_big_resources(__QRC_FILES ${CMAKE_CURRENT_BINARY_DIR}/${__RCC_OUTPUT_TARGETS}_big.qrc OPTION ${_RCC_OPTIONS})
        else()
            qt5_add_big_resources(__QRC_FILES ${CMAKE_CURRENT_BINARY_DIR}/${__RCC_OUTPUT_TARGETS}_big.qrc)
        endif()
    endif()
    
    # Add resources using standard qt5_add_resources
    if(__RCC_OPTION)
        qt5_add_resources(__QRC_FILES ${__other_rcc_files} OPTION ${_RCC_OPTIONS})
    else()
        qt5_add_resources(__QRC_FILES ${__other_rcc_files})
    endif()
    
    # Propagate the modified QRC_FILES variable
    if(__is_qrc_files)
        set(QRC_FILES ${__QRC_FILES})
        set(${QRC_FILES} ${${QRC_FILES}} PARENT_SCOPE)
    else()
        target_sources(${QRC_FILES} PUBLIC ${__QRC_FILES})
    endif()
endfunction()

### Function: qt5_add_big_resources_plus
# Purpose: Extended version of qt5_add_big_resources to handle additional resource configurations
function(qt5_add_big_resources_plus QRC_FILES)
    # Define options for parsing arguments
    set(options)
    set(oneValueArgs PREFIX OUTPUT_TARGETS)
    set(multiValueArgs FILES OPTIONS)
    
    # Parse input arguments
    cmake_parse_arguments(__RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(__other_rcc_files ${__RCC_UNPARSED_ARGUMENTS})
    # Handle output targets if not provided
    if(NOT __RCC_OUTPUT_TARGETS)
        set(__RCC_OUTPUT_TARGETS "${CMAKE_PROJECT_NAME}_big_rcc")
    endif()
    
    # Set default prefix for resources
    if(NOT __RCC_PREFIX)
        set(__RCC_PREFIX "/")
    endif()
    
    # Handle big resources
    if(__RCC_FILES)
        set(__qml_plugin_qrc_prefix ${__RCC_PREFIX})
        __generate_qrc_file(
            OUTPUT_NAME ${__RCC_OUTPUT_TARGETS}_big
            OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            FILES ${__RCC_FILES}
        )
        list(APPEND __other_rcc_files ${CMAKE_CURRENT_BINARY_DIR}/${__RCC_OUTPUT_TARGETS}_big.qrc)
    endif()
    
    # Add resources using standard qt5_add_big_resources
    if(__RCC_OPTION)
        qt5_add_big_resources(QRC_FILES ${__other_rcc_files} OPTION ${_RCC_OPTIONS})
    else()
        qt5_add_big_resources(QRC_FILES ${__other_rcc_files})
    endif()
    
    # Propagate the modified QRC_FILES variable
    set(${QRC_FILES} ${${QRC_FILES}} PARENT_SCOPE)
endfunction()

### Function: qt5_add_binary_resources_plus
# Purpose: Extended version of qt5_add_binary_resources to handle additional resource configurations
function(qt5_add_binary_resources_plus RCC_FILE)
    # Define options for parsing arguments
    set(options)
    set(oneValueArgs PREFIX OUTPUT_TARGETS)
    set(multiValueArgs FILES OPTIONS)
    
    # Parse input arguments
    cmake_parse_arguments(__RCC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(__other_rcc_files ${__RCC_UNPARSED_ARGUMENTS})
    # Handle output targets if not provided
    if(NOT __RCC_OUTPUT_TARGETS)
        set(__RCC_OUTPUT_TARGETS "${CMAKE_PROJECT_NAME}_binary_rcc")
    endif()
    
    # Set default prefix for resources
    if(NOT __RCC_PREFIX)
        set(__RCC_PREFIX "/")
    endif()
    
    # Handle binary resources
    if(__RCC_FILES)
        set(__qml_plugin_qrc_prefix ${__RCC_PREFIX})
        __generate_qrc_file(
            OUTPUT_NAME ${__RCC_OUTPUT_TARGETS}_binary
            OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            FILES ${__RCC_FILES}
        )
        list(APPEND __other_rcc_files ${CMAKE_CURRENT_BINARY_DIR}/${__RCC_OUTPUT_TARGETS}_binary.qrc)
    endif()
    
    # Add resources using standard qt5_add_binary_resources
    if(__RCC_OPTION)
        qt5_add_binary_resources(RCC_FILE ${__other_rcc_files} OPTION ${_RCC_OPTIONS})
    else()
        qt5_add_binary_resources(RCC_FILE ${__other_rcc_files})
    endif()
endfunction()

### Function: __generate_qrc_file
# Purpose: Generate a .qrc file for Qt resources, handling copying and directory structure
function(__generate_qrc_file)
    # Define options for parsing arguments
    set(options HAS_QMLDIR)
    set(oneValueArgs OUTPUT_NAME OUTPUT_DIRECTORY)
    set(multiValueArgs FILES)
    
    # Parse input arguments
    cmake_parse_arguments(__QRC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Initialize content for the .qrc file
    set(__qml_plugin_qrc_content "")
    set(__qml_plugin_resources ${FILES})
    
    # Process qmldir file if needed
    if(NOT __QRC_HAS_QMLDIR)
        set(__QRC_HAS_QMLDIR OFF)
    endif()
    if(__QRC_HAS_QMLDIR)
        string(APPEND __qml_plugin_qrc_content "        <file>qmldir</file>\n")
    endif()
    
    # Process each resource file to generate the correct path structure
    foreach(resourcefile ${__QRC_FILES})
        get_source_file_property(__rscfile_path ${resourcefile} QT_RESOURCE_ALIAS)
        if(${__rscfile_path} STREQUAL "NOTFOUND")
            if(EXISTS ${resourcefile})
                get_source_file_property(__rscfile_path ${resourcefile} LOCATION)
            else()
                set(__rscfile_path ${resourcefile})
            endif()
            string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __rscfile_path ${__rscfile_path})
        endif()
        
        get_filename_component(__rscfile_full_name ${resourcefile} NAME)
        string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __rscfile_path ${__rscfile_path})
        string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __rscfile_absolute_path ${resourcefile})
        string(REPLACE ${__rscfile_full_name} "" __rscfile_relative_dir ${__rscfile_path})
        # Generate a custom command to copy the resource file
        get_filename_component(__rscfile_ext ${resourcefile} EXT)
        if(__rscfile_ext STREQUAL ".ts" OR __rscfile_ext STREQUAL ".qm")
            add_custom_command(
                OUTPUT ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_path}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/${__rscfile_absolute_path} ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_path}
                DEPENDS ${__rscfile_full_name}-generate
                COMMENT "Copying ${__rscfile_full_name} to ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}")
        else()
            add_custom_command(
                OUTPUT ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_path}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/${__rscfile_absolute_path} ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_path}
                DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${__rscfile_absolute_path}
                COMMENT "Copying ${__rscfile_full_name} to ${__QRC_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}")
        endif()
        # Append file entry to the .qrc content
        string(APPEND __qml_plugin_qrc_content "        <file>${__rscfile_path}</file>\n")
    endforeach()
    # Generate the actual .qrc file using a template
    configure_file(${__qml_plugin_current_dir}/project.qrc.in ${__QRC_OUTPUT_DIRECTORY}/${__QRC_OUTPUT_NAME}.qrc @ONLY)
endfunction()

function(qt5_create_translation_plus _qm_files)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs OPTIONS)

    cmake_parse_arguments(_LUPDATE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_lupdate_files ${_LUPDATE_UNPARSED_ARGUMENTS})
    set(_lupdate_options ${_LUPDATE_OPTIONS})

    set(_my_sources)
    set(_my_tsfiles)
    foreach(_file ${_lupdate_files})
        get_filename_component(_ext ${_file} EXT)
        get_filename_component(_abs_FILE ${_file} ABSOLUTE)
        if(_ext MATCHES "ts")
            list(APPEND _my_tsfiles ${_abs_FILE})
        else()
            list(APPEND _my_sources ${_abs_FILE})
        endif()
    endforeach()
    foreach(_ts_file ${_my_tsfiles})
        if(_my_sources)
          # make a list file to call lupdate on, so we don't make our commands too
          # long for some systems
          get_filename_component(_ts_name ${_ts_file} NAME)
          set(_ts_lst_file "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${_ts_name}_lst_file")
          set(_lst_file_srcs)
          foreach(_lst_file_src ${_my_sources})
              set(_lst_file_srcs "${_lst_file_src}\n${_lst_file_srcs}")
          endforeach()

          get_directory_property(_inc_DIRS INCLUDE_DIRECTORIES)
          foreach(_pro_include ${_inc_DIRS})
              get_filename_component(_abs_include "${_pro_include}" ABSOLUTE)
              set(_lst_file_srcs "-I${_pro_include}\n${_lst_file_srcs}")
          endforeach()

          file(WRITE ${_ts_lst_file} "${_lst_file_srcs}")
        endif()
        add_custom_target(${_ts_name}-generate
            COMMAND ${Qt5_LUPDATE_EXECUTABLE} ${_lupdate_options} "@${_ts_lst_file}" -ts ${_ts_file}
            DEPENDS ${_my_sources}
            VERBATIM)
    endforeach()
    qt5_add_translation_plus(${_qm_files} ${_my_tsfiles})
    set(${_qm_files} ${${_qm_files}} PARENT_SCOPE)
endfunction()

function(qt5_add_translation_plus _qm_files)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs OPTIONS)

    cmake_parse_arguments(_LRELEASE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_lrelease_files ${_LRELEASE_UNPARSED_ARGUMENTS})

    foreach(_current_FILE ${_lrelease_files})
        get_filename_component(_abs_FILE ${_current_FILE} ABSOLUTE)
        get_filename_component(qm ${_abs_FILE} NAME)
        get_filename_component(tsfile ${_abs_FILE} NAME)
        # everything before the last dot has to be considered the file name (including other dots)
        string(REGEX REPLACE "\\.[^.]*$" "" FILE_NAME ${qm})
        get_source_file_property(output_location ${_abs_FILE} OUTPUT_LOCATION)
        if(output_location)
            file(MAKE_DIRECTORY "${output_location}")
            set(qm "${output_location}/${FILE_NAME}.qm")
        else()
            set(qm "${CMAKE_CURRENT_BINARY_DIR}/${FILE_NAME}.qm")
        endif()

        add_custom_target(${FILE_NAME}.qm-generate
            COMMAND ${Qt5_LRELEASE_EXECUTABLE} ${_LRELEASE_OPTIONS} ${_abs_FILE} -qm ${qm}
            BYPRODUCTS ${qm}
            DEPENDS ${tsfile}-generate VERBATIM
        )
        list(APPEND ${_qm_files} ${qm})
    endforeach()
    set(${_qm_files} ${${_qm_files}} PARENT_SCOPE)
endfunction()

### Function: qt_add_executable
# Purpose: Alias for qt5_add_executable (backward compatibility)
function(qt_add_executable)
    qt5_add_executable(${ARGV})
endfunction()

### Function: qt5_add_executable
# Purpose: Wrapper for add_executable to maintain Qt-specific conventions
function(qt5_add_executable)
    add_executable(${ARGV})
endfunction()

### Function: qt_add_library
# Purpose: Alias for qt5_add_library (backward compatibility)
function(qt_add_library)
    qt5_add_library(${ARGV})
endfunction()

### Function: qt5_add_library
# Purpose: Wrapper for add_library to maintain Qt-specific conventions
function(qt5_add_library)
    add_library(${ARGV})
endfunction()

### Function: qt_add_qml_module
# Purpose: Alias for qt5_add_qml_module (backward compatibility)
function(qt_add_qml_module)
    qt5_add_qml_module(${ARGV})
endfunction()

### Function: qt5_add_qml_module
# Purpose: Core function for defining QML modules, handling resources, typeinfo, and dependencies
function(qt5_add_qml_module TARGET)
    set(options NO_GENERATE_TYPEINFO NO_PUBLIC_SOURCES)
    set(oneValueArgs URI VERSION PLUGIN_TARGET OUTPUT_DIRECTORY RESOURCE_PREFIX TYPEINFO)
    set(multiValueArgs SOURCES QML_FILES RESOURCES DEPEND_MODULE DEPEND_MODULE_VERSION)
    
    # Parse input arguments
    cmake_parse_arguments(QMLPLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Validate that at least TARGET, URI, and VERSION are specified
    if(NOT QMLPLUGIN_URI OR NOT QMLPLUGIN_VERSION)
        message(WARNING "TARGET, URI, and VERSION must be set, no files generated")
        return()
    endif()
    
    # Process URI and version for internal use
    set(__qml_plugin_uri_name ${QMLPLUGIN_URI})
    string(REPLACE "." "_" __qml_plugin_uri_name_for_class ${QMLPLUGIN_URI})
    string(REPLACE "." "/" __qml_plugin_uri_dir ${QMLPLUGIN_URI})
    string(REPLACE "." ";" QMLPLUGIN_VERSION_LIST ${QMLPLUGIN_VERSION})
    list(GET QMLPLUGIN_VERSION_LIST 0 QMLPLUGIN_VERSION_MAJOR)
    list(GET QMLPLUGIN_VERSION_LIST 1 QMLPLUGIN_VERSION_MINOR)
    
    # Convert URI to uppercase for class naming
    string(TOUPPER ${__qml_plugin_uri_name_for_class} __qml_plugin_uri_name_for_class_upper)
    
    # Determine target type
    get_target_property(__target_type ${TARGET} TYPE)
    
    # Locate Qt binaries directory
    FindQtBinDir()
    
    # Locate qmlplugindump binary for generating plugin metadata
    FindQmlPluginDump()
    
    # Locate QML installation directory for output
    FindQtInstallQml()
    
    # Locate qmltyperegistrar binary for generating type registration files
    FindQmlTypeRegistrar()
    
    # Determine output directory based on target type
    if(NOT QMLPLUGIN_OUTPUT_DIRECTORY)
        if(__target_type MATCHES "LIBRARY")
            set(QMLPLUGIN_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_dir})
        else()
            set(QMLPLUGIN_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
        endif()
    endif()
    
    # Set QML import path for Qt Creator compatibility
    cmake_path(SET __qml_plugin_output_dir_parent NORMALIZE ${QMLPLUGIN_OUTPUT_DIRECTORY}/../)
    string(REGEX REPLACE "[/]+$" "" __qml_plugin_output_dir_parent "${__qml_plugin_output_dir_parent}")
    get_property(__qml_plugin_qml_import_path GLOBAL PROPERTY __qml_plugin_qml_import_path)
    if(__qml_plugin_qml_import_path)
        set_property(GLOBAL PROPERTY __qml_plugin_qml_import_path "${__qml_plugin_qml_import_path}:${__qml_plugin_output_dir_parent}")
    else()
        set_property(GLOBAL PROPERTY __qml_plugin_qml_import_path "${__qml_plugin_output_dir_parent}")
    endif()
    if(NOT QML_IMPORT_PATH)
        set(QML_IMPORT_PATH "${__qml_plugin_output_dir_parent}" CACHE STRING "Set for Qt Creator" FORCE)
    else()
        set(QML_IMPORT_PATH "${QML_IMPORT_PATH};${__qml_plugin_output_dir_parent}" CACHE STRING "Set for Qt Creator" FORCE)
    endif()
    get_property(__qml_plugin_qml_import_path GLOBAL PROPERTY __qml_plugin_qml_import_path)
    
    # Determine visibility of sources to public or private
    if(QMLPLUGIN_NO_PUBLIC_SOURCES OR __qml_plugin_no_public_sources)
        set(QMLPLUGIN_NO_PUBLIC_SOURCES ON)
        set(__qml_plugin_sources_flag PRIVATE)
    else()
        set(QMLPLUGIN_NO_PUBLIC_SOURCES OFF)
        set(__qml_plugin_sources_flag PUBLIC)
    endif()
    
    # Determine if typeinfo generation should be skipped
    if(QMLPLUGIN_NO_GENERATE_TYPEINFO OR __qml_plugin_no_generate_typeinfo OR (CMAKE_HOST_WIN32 AND CMAKE_BUILD_TYPE STREQUAL "Debug"))
        set(QMLPLUGIN_NO_GENERATE_TYPEINFO ON)
    else()
        set(QMLPLUGIN_NO_GENERATE_TYPEINFO OFF)
    endif()
    
    # Set default plugin target name if not provided
    if(NOT QMLPLUGIN_PLUGIN_TARGET)
        set(QMLPLUGIN_PLUGIN_TARGET "${__qml_plugin_uri_name_for_class}plugin")
    endif()
    
    # Create plugin target if it doesn't exist
    if(NOT TARGET ${QMLPLUGIN_PLUGIN_TARGET} AND __target_type MATCHES "SHARED_LIBRARY")
        add_library(${QMLPLUGIN_PLUGIN_TARGET} SHARED)
        target_link_libraries(${QMLPLUGIN_PLUGIN_TARGET} PRIVATE
                Qt${QT_VERSION_MAJOR}::Quick
        )
        add_dependencies(${TARGET} ${QMLPLUGIN_PLUGIN_TARGET})
        set(DEFAULT_TARGET ${TARGET})
        set(TARGET ${QMLPLUGIN_PLUGIN_TARGET})
    endif()
    
    # Set plugin target name
    set(__qml_plugin_target_name ${TARGET})
    
    # Set default typeinfo file name if not provided
    if(NOT QMLPLUGIN_TYPEINFO)
        set(QMLPLUGIN_TYPEINFO "${__qml_plugin_uri_name_for_class}.qmltypes")
    endif()
    
    # Set default resource prefix if not provided
    if(NOT QMLPLUGIN_RESOURCE_PREFIX)
        set(QMLPLUGIN_RESOURCE_PREFIX "/qt-project.org/imports/")
    endif()
    
    # Set default dependency module and version if not provided
    if(NOT DEFINED QMLPLUGIN_DEPEND_MODULE AND __qml_plugin_depend_module)
        set(QMLPLUGIN_DEPEND_MODULE ${__qml_plugin_depend_module})
    endif()
    
    if(NOT DEFINED QMLPLUGIN_DEPEND_MODULE_VERSION AND __qml_plugin_depend_module_version)
        set(QMLPLUGIN_DEPEND_MODULE_VERSION ${__qml_plugin_depend_module_version})
    endif()
    
    # Set output directory properties for target
    if(DEFAULT_TARGET)
        set_target_properties(${DEFAULT_TARGET} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
            LIBRARY_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
            ARCHIVE_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
            AUTOMOC_MOC_OPTIONS "--output-json;--output-dep-file")
    endif()
    
    set_target_properties(${TARGET} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        LIBRARY_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        ARCHIVE_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        AUTOMOC_MOC_OPTIONS "--output-json;--output-dep-file")
    
    # Set resource prefix for QRC file
    set(__qml_plugin_qrc_prefix "")
    if (${QMLPLUGIN_RESOURCE_PREFIX} MATCHES "/$")
        string(APPEND __qml_plugin_qrc_prefix ${QMLPLUGIN_RESOURCE_PREFIX}${__qml_plugin_uri_dir})
    else()
        string(APPEND __qml_plugin_qrc_prefix ${QMLPLUGIN_RESOURCE_PREFIX}/${__qml_plugin_uri_dir})
    endif()
    
    # Add sources and QML files to target
    target_sources(${TARGET} ${__qml_plugin_sources_flag} ${QMLPLUGIN_SOURCES} ${QMLPLUGIN_QML_FILES})
    
    # Handle library shared configurations
    if (__target_type MATCHES "LIBRARY")
        add_dependencies(${TARGET} AutoMocHelper)
        set_target_properties(${TARGET} PROPERTIES AUTOGEN_TARGET_DEPENDS AutoMocHelper)
        get_target_property(__qml_plugin_build_dir ${TARGET} AUTOGEN_BUILD_DIR)
        if(${__qml_plugin_build_dir} MATCHES "NOTFOUND")
            set(__qml_plugin_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_autogen")
        endif()
        
        # Generate automoc JSON list file
        add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
            COMMAND ${CMAKE_BINARY_DIR}/AutoMocHelper ${__qml_plugin_build_dir} > ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
            DEPENDS AutoMocHelper ${__qml_plugin_build_dir}/timestamp
            COMMENT "Generating ${TARGET}'s automoc_json_list.txt"
            COMMAND_EXPAND_LISTS
            VERBATIM)
        
        add_custom_target(${__qml_plugin_uri_name_for_class}-automoc_json_list_generate ALL
            DEPENDS AutoMocHelper ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt)
        
        # Generate collected type info file
        add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json
            COMMAND ${QT_BIN_DIR}/moc --collect-json  "@${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt" > ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
            COMMENT "Generating ${TARGET}'s collected_types.json"
            COMMAND_EXPAND_LISTS
            VERBATIM)
        add_custom_target(${__qml_plugin_uri_name_for_class}-automoc_collect_json_generate ALL
            DEPENDS AutoMocHelper ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json)
        
        # Generate type registration C++ file
        set(__qml_plugin_automoc_type_register_cpp ${CMAKE_CURRENT_BINARY_DIR}/${QMLPLUGIN_PLUGIN_TARGET}_qmltyperegistrations.cpp)
        add_custom_command(OUTPUT ${__qml_plugin_automoc_type_register_cpp}
            COMMAND ${QMLTYPEREGISTRAR_BIN} --import-name ${__qml_plugin_uri_name} --major-version ${QMLPLUGIN_VERSION_MAJOR} --minor-version ${QMLPLUGIN_VERSION_MINOR} ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json --generate-qmltypes ${CMAKE_CURRENT_BINARY_DIR}/${QMLPLUGIN_TYPEINFO} > ${__qml_plugin_automoc_type_register_cpp}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json)
        
        add_custom_target(${__qml_plugin_uri_name_for_class}-automoc_type_register_generate ALL
            DEPENDS AutoMocHelper ${__qml_plugin_automoc_type_register_cpp})
        target_sources(${TARGET} PRIVATE ${__qml_plugin_automoc_type_register_cpp})
        set_source_files_properties(${__qml_plugin_automoc_type_register_cpp} PROPERTIES SKIP_AUTOGEN ON)
    endif()
    
    # Handle static library specific configurations
    if (__target_type MATCHES "STATIC_LIBRARY")
        target_compile_definitions(${TARGET} PUBLIC
            ${__qml_plugin_uri_name_for_class_upper}_BUILD_STATIC_LIB)
    endif()
    
    # Generate qmldir file content
    set(__qml_plugin_qmldir_content "")
    if (__target_type MATCHES "STATIC_LIBRARY")
        set(__qml_plugin_static_register_content "void qml_static_register_types_${__qml_plugin_uri_name_for_class}(){\n    Q_INIT_RESOURCE(${__qml_plugin_uri_name_for_class});\n")
    endif()
    
    string(APPEND __qml_plugin_qmldir_content "module ${__qml_plugin_uri_name}\n")
    
    if (__target_type MATCHES "LIBRARY")
        if (__target_type MATCHES "SHARED_LIBRARY")
            string(APPEND __qml_plugin_qmldir_content "plugin ${QMLPLUGIN_PLUGIN_TARGET}\n")
        endif()
        string(APPEND __qml_plugin_qmldir_content "linktarget ${QMLPLUGIN_PLUGIN_TARGET}\n")
        string(APPEND __qml_plugin_qmldir_content "classname ${__qml_plugin_uri_name_for_class}Plugin\n")
    endif()
    
    string(APPEND __qml_plugin_qmldir_content "typeinfo ${QMLPLUGIN_TYPEINFO}\n")
    
    if (__target_type MATCHES "STATIC_LIBRARY")
        string(APPEND __qml_plugin_qmldir_content "prefer :${__qml_plugin_qrc_prefix}/\n")
    endif()
    
    # Process each QML file to update qmldir and generate static registration code
    foreach(qmlfile ${QMLPLUGIN_QML_FILES})
        get_source_file_property(__qmlfile_path ${qmlfile} QT_RESOURCE_ALIAS)
        get_source_file_property(__qmlfile_is_singleton ${qmlfile} QT_QML_SINGLETON_TYPE)
        get_filename_component(__qmlfile_name ${qmlfile} NAME_WE)
        get_filename_component(__qmlfile_full_name ${qmlfile} NAME)
        
        if(${__qmlfile_path} STREQUAL "NOTFOUND")
            get_source_file_property(__qmlfile_path ${qmlfile} LOCATION)
            string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __qmlfile_path ${__qmlfile_path})
        endif()
        
        string(REPLACE ${__qmlfile_full_name} "" __qmlfile_relative_dir ${__qmlfile_path})
        
        if(${__qmlfile_is_singleton} STREQUAL "NOTFOUND" OR NOT __qmlfile_is_singleton)
            string(APPEND __qml_plugin_qmldir_content "${__qmlfile_name} ${QMLPLUGIN_VERSION_MAJOR}.${QMLPLUGIN_VERSION_MINOR} ${__qmlfile_path}\n")
            if (__target_type MATCHES "STATIC_LIBRARY")
                string(APPEND __qml_plugin_static_register_content "    qmlRegisterType(")
            endif()
        else()
            string(APPEND __qml_plugin_qmldir_content "singleton ${__qmlfile_name} ${QMLPLUGIN_VERSION_MAJOR}.${QMLPLUGIN_VERSION_MINOR} ${__qmlfile_path}\n")
            if (__target_type MATCHES "STATIC_LIBRARY")
                string(APPEND __qml_plugin_static_register_content "    qmlRegisterSingletonType(")
            endif()
        endif()
        
        if (__target_type MATCHES "STATIC_LIBRARY")
            string(APPEND __qml_plugin_static_register_content "QUrl(\"qrc:${__qml_plugin_qrc_prefix}/${__qmlfile_path}\"),\"${__qml_plugin_uri_name_for_class}\",${QMLPLUGIN_VERSION_MAJOR},${QMLPLUGIN_VERSION_MINOR},\"${__qmlfile_name}\");\n")
        endif()
    endforeach()
    
    if (__target_type MATCHES "STATIC_LIBRARY")
        string(APPEND __qml_plugin_static_register_content "    qml_register_types_${__qml_plugin_uri_name_for_class}();\n}\n")
    endif()
    
    # Generate qmldir file
    configure_file(${__qml_plugin_current_dir}/qmldir.in ${QMLPLUGIN_OUTPUT_DIRECTORY}/qmldir @ONLY)
    
    # Handle dependencies on other QML modules
    if(QMLPLUGIN_DEPEND_MODULE AND __target_type MATCHES "SHARED_LIBRARY" AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
        foreach(depends ${QMLPLUGIN_DEPEND_MODULE})
            set(__qml_plugin_qmldir_content "")
            list(FIND QMLPLUGIN_DEPEND_MODULE ${depends} fake_version_index)
            list(GET QMLPLUGIN_DEPEND_MODULE_VERSION ${fake_version_index} depend_fake_version)
            if(depend_fake_version STREQUAL "NOTFOUND")
                set(depend_fake_version ${QMLPLUGIN_VERSION_MAJOR}.${QMLPLUGIN_VERSION_MINOR})
            endif()
            
            string(REPLACE "." "/" depends_dir ${depends})
            string(APPEND __qml_plugin_qmldir_content "module ${depends}\n")
            string(APPEND __qml_plugin_qmldir_content "typeinfo ${depends}.qmltypes\n")
            string(APPEND __qml_plugin_qmldir_content "Item ${depend_fake_version} Item.qml\n")
            
            configure_file(${__qml_plugin_current_dir}/qmldir.in ${__qml_plugin_output_dir_parent}/${depends_dir}/qmldir @ONLY)
            configure_file(${__qml_plugin_current_dir}/projectdepends.qml.in ${__qml_plugin_output_dir_parent}/${depends_dir}/Item.qml)
            
            # Generate dependency QML types file
            add_custom_target(${TARGET}-${depends}qmltypes ALL
                COMMAND ${QMLPLUGINDUMP_BIN} -nonrelocatable ${depends} ${depend_fake_version} ${__qml_plugin_output_dir_parent} -output "${__qml_plugin_output_dir_parent}/${depends_dir}/${depends}.qmltypes"
                COMMENT "Generating ${TARGET} depended ${depends}.qmltypes"
                DEPENDS ${TARGET})
        endforeach()
    endif()
    
    # Generate QRC file based on target type
    if (NOT __target_type MATCHES "SHARED_LIBRARY")
        __generate_qrc_file(
            HAS_QMLDIR ON
            OUTPUT_NAME ${__qml_plugin_uri_name_for_class}
            OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
            FILES ${QMLPLUGIN_RESOURCES} ${QMLPLUGIN_QML_FILES}
        )
    else()
        __generate_qrc_file(
            HAS_QMLDIR OFF
            OUTPUT_NAME ${__qml_plugin_uri_name_for_class}
            OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
            FILES ${QMLPLUGIN_RESOURCES} ${QMLPLUGIN_QML_FILES}
        )
    endif()
    
    # Add the generated QRC file to the target
    qt5_add_resources(__qml_plugin_qrc_file ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__qml_plugin_uri_name_for_class}.qrc)
    target_sources(${TARGET} PRIVATE ${__qml_plugin_qrc_file})
    
    # Generate QML type info file if needed for shared libraries
    if (__target_type MATCHES "SHARED_LIBRARY" AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
        set(__qmltypes_depend ${TARGET})
        if(QMLPLUGIN_DEPEND_MODULE AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
            list(GET QMLPLUGIN_DEPEND_MODULE 0 __qmltypes_depend)
            set(__qmltypes_depend ${TARGET}-${__qmltypes_depend}qmltypes)
        endif()
        
        # Generate target-specific QML types file
        add_custom_target(${TARGET}qmltypes ALL
            DEPENDS ${__qmltypes_depend}
            COMMAND ${CMAKE_COMMAND} -E env QML2_IMPORT_PATH="${__qml_plugin_qml_import_path}" ${QMLPLUGINDUMP_BIN} -nonrelocatable ${QMLPLUGIN_URI} ${QMLPLUGIN_VERSION_MAJOR}.${QMLPLUGIN_VERSION_MINOR} ${__qml_plugin_output_dir_parent} -output ${QMLPLUGIN_OUTPUT_DIRECTORY}/${QMLPLUGIN_TYPEINFO}
            COMMENT "Generating ${QMLPLUGIN_TYPEINFO}")
    endif()
    
    ### Generate Plugin Class Implementation
    if (__target_type MATCHES "LIBRARY")
        if (__target_type MATCHES "STATIC_LIBRARY")
            configure_file(${__qml_plugin_current_dir}/URIplugin_init.cpp.in ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_for_class}plugin_init.cpp @ONLY)
            target_sources(${TARGET} PRIVATE
                "${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_for_class}plugin_init.cpp")
            target_compile_definitions(${TARGET}
                PUBLIC
                QT_STATICPLUGIN
            )
        endif()
        
        configure_file(${__qml_plugin_current_dir}/project_URIPlugin.cpp.in ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_target_name}_${__qml_plugin_uri_name_for_class}Plugin.cpp @ONLY)
        target_sources(${TARGET} PRIVATE
            "${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_target_name}_${__qml_plugin_uri_name_for_class}Plugin.cpp")
    endif()
endfunction()
