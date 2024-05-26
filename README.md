# Qt5QMLPlugin

A cmake plugin add qt_add_qml_module function for Qt 5 users to build QML modules like Qt 6.
There is no other work need to be done, just use it!

## Specificities

1. The naming and functionality is basically the same as Qt's own qt_add_qml_module, which means that very little needs to be modified(can be use like `qt_add_qml_module` or `qt5_add_qml_module`).
2. All resource files, including qml files, will be automatically copied to the directory after modification without manual operation.
3. All plugin-related files (qmldir, qml extension plugin's source code, qrc file, etc.) will be automatically generated in the build directory, no need to write them manually and without polluting the code repository (just like Qt6😉).
4. Provide `qt_add_library` and `qt5_add_library` functions for easy code migration.

## Usage

### Syntax
```cmake
qt_add_qml_module(<TARGET>
    URI <uri>
    VERSION <version>
    PLUGIN_TARGET <plugin target name>
    OUTPUT_DIRECTORY <plugin library target output directory>
    RESOURCE_PREFIX <prefix for qrc file>
    TYPEINFO <typeinfo file(.qmltypes) name>
    SOURCES
        sourceFile1 [sourceFile2 ...]
    QML_FILES
        [qmlFile1 qmlFile2 ...]
    RESOURCES
        [resourceFile1 resourceFile2]
    DEPEND_MODULE
        [dependModule1 dependModule2]
    NO_GENERATE_TYPEINFO <ON or OFF>
)
```
#### Explanation
| Argument        | Explanation |
| ------------ |:--------------|
| `URI`        | URI used by the plugin, which is also used as a directory when installing the plugin. For example `org.mycompany.components` will be installed to `${QT_QML_INSTALL_DIR}/org/mycompany/components`. |
| `VERSION`    | Denotes the version of the plugin. |
| `SOURCES`    | Should contain all the C++ sources to be compiled with this plugin. |
| `QML_FILES`   | Should contain all QML files which should be copied to the `${QT_QML_INSTALL_DIR}/org/mycompany/components` directory. It will be added to qrc file too. |
| `RESOURCES` | The files which will be added to the qrc files. |
| `DEPEND_MODULE` | The 3rdparty module your module need but `qmlplugindump` couldn't find, add it name to this, it will generate a fake module to bypass the `qmlplugindump`'s check. A little trick to let typeinfo file be normally generated. |
| `RESOURCE_PREFIX` | A prefix that will be used in qrc file system. |
| `PLUGIN_TARGET` | Default is the lowercase URI. Change it if you like. |
| `OUTPUT_DIRECTORY` | Default is ${CMAKE_CURRENT_BINARY_DIR}/org/mycompany/components. Change it if you like. |
| `TYPEINFO` | Default name is the URI without `.`, like `orgmycompanycomponents.qmltypes`. Change it if you like. |
| `NO_GENERATE_TYPEINFO` | Turn off typeinfo file auto generation. Default is OFF. |

### Example
```cmake
qt_add_qml_module(components
URI org.mycompany.components
VERSION 1.0
SOURCES
    src/componentsplugin.h
    src/componentsplugin.cpp
    src/filemonitor/filemonitor.h
    src/filemonitor/filemonitor.cpp
QML_FILES
    qml/Dashboard.qml
    qml/TriangleButton.qml
RESOURCES
    resources/icon.png
)
```

## Acknowledgement

Thanks to pntzio's [cmake-qmlplugin](https://github.com/pntzio/cmake-qmlplugin) for the reference and inspiration.