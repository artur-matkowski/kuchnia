cmake_minimum_required(VERSION 3.21)

project(qt-qml-hmi VERSION 1.0 LANGUAGES CXX)

# Gui rather than Widgets: there is no window system on the target and no widget on
# either. Quick pulls the scene graph; Qml pulls the engine main.cpp drives.
find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(qt-hmi src/main.cpp)

set(QT_HMI_QML
	src/qml/Main.qml
	src/qml/SpinningTriangle.qml
)

# Each QML file keeps its path relative to this file inside the module unless aliased,
# so Main.qml would answer to qrc:/qt/qml/QtHmi/src/qml/Main.qml and the generated
# qmldir would carry this repository's directory layout. It resolves either way; the
# alias is what keeps the module's public shape independent of where the sources sit.
foreach(qml IN LISTS QT_HMI_QML)
	get_filename_component(name "${qml}" NAME)
	set_source_files_properties("${qml}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
endforeach()

# URI QtHmi is the string main.cpp passes to loadFromModule(); they are one fact in two
# files and nothing checks that they agree - a mismatch is a runtime "module is not
# installed", not a build failure.
qt_add_qml_module(qt-hmi
	URI QtHmi
	VERSION 1.0
	QML_FILES ${QT_HMI_QML}
)

target_link_libraries(qt-hmi PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)

include(GNUInstallDirs)
install(TARGETS qt-hmi RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
