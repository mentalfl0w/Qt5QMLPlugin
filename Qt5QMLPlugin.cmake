include(CMakeParseArguments)
set(__qml_plugin_current_dir ${CMAKE_CURRENT_LIST_DIR})
option(__qml_plugin_no_generate_typeinfo OFF)
option(__qml_plugin_no_public_sources ON)
find_package(Qt5 REQUIRED COMPONENTS Core)
### Finds where to qmlplugindump binary is installed
function(FindQmlPluginDump)
    cmake_path(SET QT_BIN_DIR NORMALIZE ${Qt5_DIR}/../../../bin)
    set(QMLPLUGINDUMP_BIN ${QT_BIN_DIR}/qmlplugindump PARENT_SCOPE)
endfunction()

function(FindQmlTypeRegistrar)
    cmake_path(SET QT_BIN_DIR NORMALIZE ${Qt5_DIR}/../../../bin)
    set(QMLTYPEREGISTRAR_BIN ${QT_BIN_DIR}/qmltyperegistrar PARENT_SCOPE)
endfunction()

### Sets QT_QML_INSTALL_DIR to the directory where QML Plugins should be installed
function(FindQtInstallQml)
    cmake_path(SET QT_ROOT_DIR NORMALIZE ${Qt5_DIR}/../../../)
    set(QT_QML_INSTALL_DIR ${QT_ROOT_DIR}qml PARENT_SCOPE)
endfunction()

function(qt_add_executable)
    qt5_add_executable(${ARGV})
endfunction()

function(qt5_add_executable)
    add_executable(${ARGV})
endfunction()

function(qt_add_library)
    qt5_add_library(${ARGV})
endfunction()

function(qt5_add_library)
    add_library(${ARGV})
endfunction()

function(qt_add_qml_module)
    qt5_add_qml_module(${ARGV})
endfunction()

function(qt5_add_qml_module TARGET)
    set(options NO_GENERATE_TYPEINFO NO_PUBLIC_SOURCES)
    set(oneValueArgs URI VERSION PLUGIN_TARGET OUTPUT_DIRECTORY RESOURCE_PREFIX TYPEINFO)
    set(multiValueArgs SOURCES QML_FILES RESOURCES DEPEND_MODULE)
    cmake_parse_arguments(QMLPLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    ### At least TARGET, URI and VERSION must be specified
    if(NOT QMLPLUGIN_URI OR NOT QMLPLUGIN_VERSION)
        message(WARNING "TARGET,URI,VERSION must be set, no files generated")
        return()
    endif()

    set(__qml_plugin_target_name ${TARGET})
    set(__qml_plugin_uri_name ${QMLPLUGIN_URI})
    string(REPLACE "." "" __qml_plugin_uri_name_fix ${QMLPLUGIN_URI})
    string(REPLACE "." "/" __qml_plugin_uri_dir ${QMLPLUGIN_URI})
    string(REPLACE "." ";" QMLPLUGIN_VERSION_LIST ${QMLPLUGIN_VERSION})
    list(GET QMLPLUGIN_VERSION_LIST 0 QMLPLUGIN_VERSION_MAJOR)
    list(GET QMLPLUGIN_VERSION_LIST 1 QMLPLUGIN_VERSION_MINOR)

    string(TOLOWER ${__qml_plugin_uri_name_fix} __qml_plugin_uri_name_lower)
    string(TOUPPER ${__qml_plugin_uri_name_fix} __qml_plugin_uri_name_upper)
    string(TOLOWER ${TARGET} __qml_plugin_target_name_lower)
    string(TOUPPER ${TARGET} __qml_plugin_target_name_upper)

    ### Depending on project hierarchy, one might want to specify a custom binary dir
    if(NOT QMLPLUGIN_OUTPUT_DIRECTORY)
        set(QMLPLUGIN_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_dir})
    endif()

    if(QMLPLUGIN_NO_PUBLIC_SOURCES OR __qml_plugin_no_public_sources)
        set(QMLPLUGIN_NO_PUBLIC_SOURCES ON)
        set(__qml_plugin_sources_flag PRIVATE)
    else()
        set(QMLPLUGIN_NO_PUBLIC_SOURCES OFF)
        set(__qml_plugin_sources_flag PUBLIC)
    endif()

    if(QMLPLUGIN_NO_GENERATE_TYPEINFO OR __qml_plugin_no_generate_typeinfo)
        set(QMLPLUGIN_NO_GENERATE_TYPEINFO ON)
    else()
        set(QMLPLUGIN_NO_GENERATE_TYPEINFO OFF)
    endif()

    ### Set target output directory
    set_target_properties(${TARGET} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        LIBRARY_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        ARCHIVE_OUTPUT_DIRECTORY ${QMLPLUGIN_OUTPUT_DIRECTORY}
        AUTOMOC_MOC_OPTIONS "--output-json;--output-dep-file;-Muri=${__qml_plugin_uri_name_fix}")
    cmake_path(SET QT_BIN_DIR NORMALIZE ${Qt5_DIR}/../../../bin)

    if(NOT QMLPLUGIN_PLUGIN_TARGET)
        set(QMLPLUGIN_PLUGIN_TARGET "${__qml_plugin_uri_name_fix}plugin")
    endif()

    if(NOT QMLPLUGIN_TYPEINFO)
        set(QMLPLUGIN_TYPEINFO "${__qml_plugin_uri_name_fix}.qmltypes")
    endif()

    if(NOT QMLPLUGIN_RESOURCE_PREFIX)
        set(QMLPLUGIN_RESOURCE_PREFIX "/qt-project.org/imports/")
    endif()
    set(__qml_plugin_qrc_prefix "")
    if (${QMLPLUGIN_RESOURCE_PREFIX} MATCHES "/$")
        string(APPEND __qml_plugin_qrc_prefix ${QMLPLUGIN_RESOURCE_PREFIX}${__qml_plugin_uri_dir})
    else()
        string(APPEND __qml_plugin_qrc_prefix ${QMLPLUGIN_RESOURCE_PREFIX}/${__qml_plugin_uri_dir})
    endif()

    ### Find location of qmlplugindump (stored in QMLPLUGINDUMP_BIN)
    FindQmlPluginDump()
    ### Find where to install QML Plugins (stored in QT_QML_INSTALL_DIR)
    FindQtInstallQml()
    FindQmlTypeRegistrar()

    ### Append sources files to target
    add_executable(AutoMocHelper ${__qml_plugin_current_dir}/automoc_helper.cpp)
    target_link_libraries(AutoMocHelper Qt5::Core)
    add_dependencies(${TARGET} AutoMocHelper)
    set_target_properties(${TARGET} PROPERTIES AUTOGEN_TARGET_DEPENDS AutoMocHelper)
    get_target_property(__qml_plugin_build_dir ${TARGET} AUTOGEN_BUILD_DIR)
    if(${__qml_plugin_build_dir} MATCHES "NOTFOUND")
        set(__qml_plugin_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_autogen")
    endif()

    message("${__qml_plugin_build_dir}")

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
        COMMAND ${CMAKE_CURRENT_BINARY_DIR}/AutoMocHelper ${__qml_plugin_build_dir} > ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/AutoMocHelper ${__qml_plugin_build_dir}/timestamp
        COMMAND_EXPAND_LISTS
        VERBATIM)

    add_custom_target(automoc_json_list_generate ALL
        DEPENDS AutoMocHelper ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt)

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json
        COMMAND ${QT_BIN_DIR}/moc --collect-json  "@${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt" > ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/automoc_json_list.txt
        COMMAND_EXPAND_LISTS
        VERBATIM)
    add_custom_target(automoc_collect_json_generate ALL
        DEPENDS AutoMocHelper ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json)


    set(__qml_plugin_automoc_type_register_cpp "${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_lower}_qmltyperegistrations.cpp")
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_lower}_qmltyperegistrations.cpp
        COMMAND ${QMLTYPEREGISTRAR_BIN} --import-name ${__qml_plugin_uri_name} --major-version ${QMLPLUGIN_VERSION_MAJOR} --minor-version 0 ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json --generate-qmltypes ${CMAKE_CURRENT_BINARY_DIR}/${QMLPLUGIN_TYPEINFO} > ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_lower}_qmltyperegistrations.cpp
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/collected_types.json)

    add_custom_target(automoc_type_register_generate ALL
        DEPENDS AutoMocHelper ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name_lower}_qmltyperegistrations.cpp)

    target_sources(${TARGET} ${__qml_plugin_sources_flag} ${QMLPLUGIN_SOURCES} ${QMLPLUGIN_QML_FILES})
    target_sources(${TARGET} PRIVATE ${__qml_plugin_automoc_type_register_cpp})
    set_source_files_properties(${__qml_plugin_automoc_type_register_cpp} PROPERTIES SKIP_AUTOMOC ON)
    get_target_property(__target_type ${TARGET} TYPE)

    if (__target_type MATCHES "STATIC_LIBRARY")
        target_compile_definitions(${TARGET} PUBLIC
            ${__qml_plugin_target_name_upper}_BUILD_STATIC_LIB)
    endif()

    ### Generate qmldir
    if(QMLPLUGIN_QML_FILES)
        set(__qml_plugin_qmldir_content "")
        if (__target_type MATCHES "STATIC_LIBRARY")
            set(__qml_plugin_static_register_content "void qml_static_register_types_${__qml_plugin_uri_name}(){\n    Q_INIT_RESOURCE(${__qml_plugin_uri_name_lower});\n")
        endif()
        string(APPEND __qml_plugin_qmldir_content "module ${__qml_plugin_uri_name}\n")
        if (__target_type MATCHES "LIBRARY")
            if (__target_type MATCHES "SHARED_LIBRARY")
                if(NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
                    add_custom_target(ForceConfiguration ALL
                        DEPENDS ${TARGET}
                        COMMAND ${CMAKE_COMMAND} -H${CMAKE_SOURCE_DIR} -B${CMAKE_BINARY_DIR})
                endif()
                string(APPEND __qml_plugin_qmldir_content "plugin ${QMLPLUGIN_PLUGIN_TARGET}\n")
            endif()
            string(APPEND __qml_plugin_qmldir_content "linktarget ${QMLPLUGIN_PLUGIN_TARGET}\n")
            string(APPEND __qml_plugin_qmldir_content "classname ${__qml_plugin_uri_name_fix}Plugin\n")
        endif()
        string(APPEND __qml_plugin_qmldir_content "typeinfo ${QMLPLUGIN_TYPEINFO}\n")
        if (__target_type MATCHES "STATIC_LIBRARY")
            string(APPEND __qml_plugin_qmldir_content "prefer :${__qml_plugin_qrc_prefix}/\n")
        endif()
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
                string(APPEND __qml_plugin_qmldir_content "${__qmlfile_name} ${QMLPLUGIN_VERSION_MAJOR}.0 ${__qmlfile_path}\n")
                if (__target_type MATCHES "STATIC_LIBRARY")
                    string(APPEND __qml_plugin_static_register_content "    qmlRegisterType(")
                endif()
            else()
                string(APPEND __qml_plugin_qmldir_content "singleton ${__qmlfile_name} ${QMLPLUGIN_VERSION_MAJOR}.0 ${__qmlfile_path}\n")
                if (__target_type MATCHES "STATIC_LIBRARY")
                    string(APPEND __qml_plugin_static_register_content "    qmlRegisterSingletonType(")
                endif()
            endif()
            if (__target_type MATCHES "STATIC_LIBRARY")
                string(APPEND __qml_plugin_static_register_content "QUrl(\"qrc:${__qml_plugin_qrc_prefix}/${__qmlfile_path}\"),\"${__qml_plugin_uri_name}\",${QMLPLUGIN_VERSION_MAJOR},0,\"${__qmlfile_name}\");\n")
            endif()
        endforeach()
        if (__target_type MATCHES "STATIC_LIBRARY")
            string(APPEND __qml_plugin_static_register_content "    qml_register_types_${__qml_plugin_uri_name}();\n}\n")
        endif()
        configure_file(${__qml_plugin_current_dir}/qmldir.in ${QMLPLUGIN_OUTPUT_DIRECTORY}/qmldir @ONLY)
        if(QMLPLUGIN_DEPEND_MODULE AND __target_type MATCHES "SHARED_LIBRARY" AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
            set(__qml_plugin_qmldir_content "")
            foreach(depends ${QMLPLUGIN_DEPEND_MODULE})
                string(APPEND __qml_plugin_qmldir_content "module ${depends}\n")
                string(APPEND __qml_plugin_qmldir_content "typeinfo ${depends}.qmltypes\n")
                string(APPEND __qml_plugin_qmldir_content "${depends} 1.0 ${depends}.qml\n")
                configure_file(${__qml_plugin_current_dir}/qmldir.in ${QMLPLUGIN_OUTPUT_DIRECTORY}/${depends}/qmldir @ONLY)
                configure_file(${__qml_plugin_current_dir}/projectdepends.qml.in ${QMLPLUGIN_OUTPUT_DIRECTORY}/${depends}/${depends}.qml)
                add_custom_target(${depends}qmltypes ALL
                    DEPENDS ForceConfiguration
                    COMMAND ${QMLPLUGINDUMP_BIN} -nonrelocatable ${depends} 1.0 ${QMLPLUGIN_OUTPUT_DIRECTORY} > ${QMLPLUGIN_OUTPUT_DIRECTORY}/${depends}/${depends}.qmltypes
                    COMMENT "Generating ${depends}.qmltypes")
            endforeach()
        endif()
    endif()

    ### Generate qrc file
    if(QMLPLUGIN_RESOURCES)
        set(__qml_plugin_qrc_content "")
        set(__qml_plugin_resources ${QMLPLUGIN_RESOURCES} ${QMLPLUGIN_QML_FILES})
        if (NOT __target_type MATCHES "SHARED_LIBRARY")
            string(APPEND __qml_plugin_qrc_content "        <file>qmldir</file>\n")
        endif()
        foreach(resourcefile ${__qml_plugin_resources})
            get_source_file_property(__rscfile_path ${resourcefile} QT_RESOURCE_ALIAS)
            if(${__rscfile_path} STREQUAL "NOTFOUND")
                get_source_file_property(__rscfile_path ${resourcefile} LOCATION)
                string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __rscfile_path ${__rscfile_path})
            endif()
            get_filename_component(__rscfile_full_name ${resourcefile} NAME)
            string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" __rscfile_path ${__rscfile_path})
            string(REPLACE ${__rscfile_full_name} "" __rscfile_relative_dir ${__rscfile_path})
            add_custom_command(
                OUTPUT ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__rscfile_path}
                COMMAND ${CMAKE_COMMAND} -E make_directory ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/${resourcefile} ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__rscfile_path}
                DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${resourcefile}
                COMMENT "Copying ${__rscfile_full_name} to ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__rscfile_relative_dir}")
            string(APPEND __qml_plugin_qrc_content "        <file>${__rscfile_path}</file>\n")
        endforeach()
        configure_file(${__qml_plugin_current_dir}/project.qrc.in ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__qml_plugin_uri_name_lower}.qrc @ONLY)
        target_sources(${TARGET} ${__qml_plugin_sources_flag} ${QMLPLUGIN_OUTPUT_DIRECTORY}/${__qml_plugin_uri_name_lower}.qrc)
    endif()

    ### Generate qmltypes
    if (__target_type MATCHES "SHARED_LIBRARY" AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
        set(__qmltypes_depend ${TARGET})
        if(QMLPLUGIN_DEPEND_MODULE AND NOT QMLPLUGIN_NO_GENERATE_TYPEINFO)
            list(GET QMLPLUGIN_DEPEND_MODULE 0 __qmltypes_depend)
            set(__qmltypes_depend ${__qmltypes_depend}qmltypes)
        endif()
        add_custom_target(${TARGET}qmltypes ALL
            DEPENDS ${__qmltypes_depend}
            COMMAND ${QMLPLUGINDUMP_BIN} -nonrelocatable ${QMLPLUGIN_URI} ${QMLPLUGIN_VERSION_MAJOR}.0 ${QMLPLUGIN_OUTPUT_DIRECTORY}/../ > ${QMLPLUGIN_OUTPUT_DIRECTORY}/${QMLPLUGIN_TYPEINFO}
            COMMENT "Generating ${QMLPLUGIN_TYPEINFO}")
        foreach(depends ${QMLPLUGIN_DEPEND_MODULE})
            add_custom_target(${depends}clean ALL
                DEPENDS ${TARGET}qmltypes
                COMMAND ${CMAKE_COMMAND} -E remove_directory ${QMLPLUGIN_OUTPUT_DIRECTORY}/${depends}
                COMMENT "Removing unused ${depends} directory.")
        endforeach()
    endif()


    ### Generate ${TARGET}Plugin class
    if (__target_type MATCHES "LIBRARY")
        if (__target_type MATCHES "STATIC_LIBRARY")
            configure_file(${__qml_plugin_current_dir}/URIplugin_init.cpp.in ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name}plugin_init.cpp @ONLY)
            target_sources(${TARGET} ${__qml_plugin_sources_flag}
                "${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_uri_name}plugin_init.cpp")
            target_compile_definitions(${TARGET}
                PUBLIC
                QT_STATICPLUGIN
            )
        endif()
        configure_file(${__qml_plugin_current_dir}/project_URIPlugin.cpp.in ${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_target_name}_${__qml_plugin_uri_name}Plugin.cpp @ONLY)
        target_sources(${TARGET} ${__qml_plugin_sources_flag}
            "${CMAKE_CURRENT_BINARY_DIR}/${__qml_plugin_target_name}_${__qml_plugin_uri_name}Plugin.cpp")
    endif()
endfunction()
