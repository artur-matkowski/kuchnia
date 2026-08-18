cmake_minimum_required(VERSION 3.21)

project(qt-qml-hmi VERSION 1.0 LANGUAGES CXX)

# Gui rather than Widgets: there is no window system on the target and no widget on
# either. Quick pulls the scene graph; Qml pulls the engine main.cpp drives.
find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml Quick)

# NetSSL is not optional: rest-url defaults to an https endpoint, and Poco resolves the
# scheme at runtime - a build without it fetches http fine and throws on the first https
# request, which reads as a network fault rather than a missing component.
find_package(Poco REQUIRED COMPONENTS Foundation Net NetSSL JSON)
find_package(PahoMqttCpp REQUIRED)

# libpqxx ships no CMake config package on either target; both install a pkg-config file.
find_package(PkgConfig REQUIRED)
pkg_check_modules(PQXX REQUIRED IMPORTED_TARGET libpqxx)

qt_standard_project_setup(REQUIRES 6.5)

# Both modules are consumed as source rather than as libraries: neither installs anything,
# and one of them needs its MAX_LOG_LEVEL fixed at compile time by whoever builds it.
#
# An uninitialised submodule is an empty directory, which CMake would otherwise report as a
# missing source file naming a path that plainly exists.
foreach(module Module-cpp-config Module-cpp-logger)
	if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/deps/${module}/src")
		message(FATAL_ERROR
			"deps/${module} is empty - run: git submodule update --init --recursive")
	endif()
endforeach()

add_library(qt-hmi-modules STATIC
	deps/Module-cpp-config/src/Config.cpp
	deps/Module-cpp-logger/src/Logger.cpp
	deps/Module-cpp-logger/src/TIme.cpp
)

target_include_directories(qt-hmi-modules PUBLIC
	deps/Module-cpp-config/src
	deps/Module-cpp-logger/src
)

set_target_properties(qt-hmi-modules PROPERTIES POSITION_INDEPENDENT_CODE ON)

qt_add_executable(qt-hmi
	src/main.cpp
	src/integrations/Database.cpp
	src/integrations/Integrations.cpp
	src/integrations/Log.cpp
	src/integrations/Mqtt.cpp
	src/integrations/Rest.cpp
	src/integrations/Service.cpp
	src/integrations/Settings.cpp
)

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

target_link_libraries(qt-hmi PRIVATE
	Qt6::Gui
	Qt6::Qml
	Qt6::Quick
	qt-hmi-modules
	Poco::Foundation
	Poco::Net
	Poco::NetSSL
	Poco::JSON
	PahoMqttCpp::paho-mqttpp3
	PkgConfig::PQXX
)

include(GNUInstallDirs)
install(TARGETS qt-hmi RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
