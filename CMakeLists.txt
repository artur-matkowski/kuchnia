cmake_minimum_required(VERSION 3.21)

project(qt-qml-hmi VERSION 1.0 LANGUAGES CXX)

# cmake/ holds FindPoco.cmake, which takes precedence over any PocoConfig.cmake the machine
# happens to have: find_package's basic signature tries MODULE before CONFIG. That is
# deliberate - one discovery path for both targets, and only one of them ships a config
# package. See cmake/FindPoco.cmake.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Gui rather than Widgets: there is no window system on the target and no widget on
# either. Quick pulls the scene graph; Qml pulls the engine main.cpp drives.
#
# Multimedia links, but the QML import comes from a plugin loaded at runtime, and so does the
# backend that decodes anything - a build that links fine still plays nothing on an image
# missing either. See docs/media.md.
find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Multimedia Qml Quick)

# NetSSL is not optional: rest-url defaults to an https endpoint, and Poco resolves the
# scheme at runtime - a build without it fetches http fine and throws on the first https
# request, which reads as a network fault rather than a missing component.
find_package(Poco REQUIRED COMPONENTS Foundation Net NetSSL JSON)
find_package(PahoMqttCpp REQUIRED)

# libpqxx ships no CMake config package on either target; both install a pkg-config file.
find_package(PkgConfig REQUIRED)

# A sysroot constrains find_library and find_path, but pkg-config keeps its own search path
# and ignores all of it. Left alone it reads the build machine's .pc files, and a sysroot
# prefix is then pasted onto their -I and -L - which lands on real directories often enough
# to configure, link, and produce a binary built against the wrong library's metadata.
if(CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT)
	set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
endif()

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
	src/app/AppState.cpp
	src/app/Cameras.cpp
	src/app/Gate.cpp
	src/app/HotWater.cpp
	src/app/Panel.cpp
	src/app/Radio.cpp
	src/app/Series.cpp
	src/app/Weather.cpp
	src/integrations/Database.cpp
	src/integrations/Integrations.cpp
	src/integrations/Log.cpp
	src/integrations/Mqtt.cpp
	src/integrations/Rest.cpp
	src/integrations/Service.cpp
	src/integrations/Settings.cpp
)

set(QT_HMI_QML
	src/qml/Button.qml
	src/qml/Card.qml
	src/qml/CardFrame.qml
	src/qml/CameraTile.qml
	src/qml/CamerasScreen.qml
	src/qml/Carousel.qml
	src/qml/CarouselIn.qml
	src/qml/CarouselOut.qml
	src/qml/CarouselWeather.qml
	src/qml/Cells.qml
	src/qml/ChartCard.qml
	src/qml/Clock.qml
	src/qml/CompactScreen.qml
	src/qml/ConditionsCard.qml
	src/qml/Context.qml
	src/qml/ForecastCard.qml
	src/qml/ForecastSpan.qml
	src/qml/GatePanel.qml
	src/qml/Gauge.qml
	src/qml/HotWaterPanel.qml
	src/qml/LineChart.qml
	src/qml/Main.qml
	src/qml/Nav.qml
	src/qml/RadioPanel.qml
	src/qml/RainChanceCard.qml
	src/qml/SceneElement.qml
	src/qml/SegmentedBar.qml
	src/qml/SettingsScreen.qml
	src/qml/StatusBadge.qml
	src/qml/TemperatureCard.qml
	src/qml/Theme.qml
	src/qml/WeatherLayer.qml
	src/qml/WeatherScreen.qml
	src/qml/WindCard.qml
)

# Each QML file keeps its path relative to this file inside the module unless aliased,
# so Main.qml would answer to qrc:/qt/qml/QtHmi/src/qml/Main.qml and the generated
# qmldir would carry this repository's directory layout. It resolves either way; the
# alias is what keeps the module's public shape independent of where the sources sit.
foreach(qml IN LISTS QT_HMI_QML)
	get_filename_component(name "${qml}" NAME)
	set_source_files_properties("${qml}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
endforeach()

# These five carry `pragma Singleton`, which is only half of what a singleton needs: without
# this the generated qmldir does not declare it, and every `Theme.`, `Nav.`, `Cells.`,
# `ForecastSpan.` and `Carousel.` in the scene resolves to undefined - an unstyled screen with
# every panel at the origin, which does not answer the arrow keys, rather than an error.
set_source_files_properties(src/qml/Theme.qml src/qml/Nav.qml src/qml/ForecastSpan.qml
	src/qml/Cells.qml src/qml/Carousel.qml
	PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# URI QtHmi is the string main.cpp passes to loadFromModule() and the one AppState registers
# its singletons under; they are one fact in three places and nothing checks that they agree -
# a mismatch is a runtime "module is not installed" or "is not a type", not a build failure.
qt_add_qml_module(qt-hmi
	URI QtHmi
	VERSION 1.0
	QML_FILES ${QT_HMI_QML}
)

# A plain resource rather than the QML module's RESOURCES, which would put these under
# :/qt/qml/QtHmi/. main.cpp opens :/fonts/LiberationSans-Regular.ttf by that name, and
# addApplicationFont() reports a path that does not exist exactly as it reports a corrupt
# font: -1, and a screen with no text on it.
qt_add_resources(qt-hmi "fonts"
	PREFIX "/fonts"
	BASE assets/fonts
	FILES
		assets/fonts/LiberationSans-Regular.ttf
		assets/fonts/LiberationSans-Bold.ttf
)

# src/ on the path, so an include reads the same wherever it is written: src/app/ and
# src/integrations/ include each other by their repo-relative names rather than by "../".
target_include_directories(qt-hmi PRIVATE src)

target_link_libraries(qt-hmi PRIVATE
	Qt6::Gui
	Qt6::Multimedia
	Qt6::Qml
	Qt6::Quick
	qt-hmi-modules
	Poco::Foundation
	Poco::Net
	Poco::NetSSL
	Poco::JSON
	PahoMqttCpp::paho-mqttpp3
	PkgConfig::PQXX

	# main.cpp resolves libav's log entry points at runtime rather than linking ffmpeg -
	# the backend that carries them is a plugin. Empty on a glibc that has dlsym in libc.
	${CMAKE_DL_LIBS}
)

include(GNUInstallDirs)
install(TARGETS qt-hmi RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
