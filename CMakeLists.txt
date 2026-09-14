cmake_minimum_required(VERSION 3.21)

project(kuchnia VERSION 1.0 LANGUAGES CXX)

# Gui rather than Widgets: the scene is Quick end to end and there is no widget anywhere in
# it. Quick pulls the scene graph; Qml pulls the engine main.cpp drives.
#
# Multimedia links, but the QML import comes from a plugin loaded at runtime, and so does the
# backend that decodes anything - a build that links fine still plays nothing on a board
# missing either. See docs/media.md.
find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Multimedia Qml Quick)

# NetSSL is not optional: rest-url defaults to an https endpoint, and Poco resolves the
# scheme at runtime - a build without it fetches http fine and throws on the first https
# request, which reads as a network fault rather than a missing component.
find_package(Poco CONFIG REQUIRED COMPONENTS Foundation Net NetSSL JSON)
find_package(PahoMqttCpp REQUIRED)

# libpqxx ships no CMake config package; it installs a pkg-config file instead.
find_package(PkgConfig REQUIRED)

pkg_check_modules(PQXX REQUIRED IMPORTED_TARGET libpqxx)

qt_standard_project_setup(REQUIRES 6.5)

# What the settings screen prints, and the one string in the process that says which build
# this is. The package passes debian/changelog's version, which is the version apt installed
# and the only one a board can be asked about - see docs/packaging.md. A desktop build has no
# changelog speaking for it and folds one out of the history instead - docs/versioning.md.
#
# Resolved at configure time, so a desktop build that has moved on since keeps the version it
# was configured with until CMake runs again. Uncommitted work never appears in it at all:
# the number names the last commit, whatever the tree looks like.
set(KUCHNIA_VERSION "" CACHE STRING "Version the application reports; empty asks versioner")

if(NOT KUCHNIA_VERSION)
	# versioner reads the repository from the working directory, not from its own location.
	execute_process(
		COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/versioner/bin/versioner" version
		WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
		OUTPUT_VARIABLE KUCHNIA_VERSION
		OUTPUT_STRIP_TRAILING_WHITESPACE
		ERROR_QUIET
	)
endif()

if(NOT KUCHNIA_VERSION)
	set(KUCHNIA_VERSION "unknown")
endif()

message(STATUS "kuchnia version: ${KUCHNIA_VERSION}")

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

add_library(kuchnia-modules STATIC
	deps/Module-cpp-config/src/Config.cpp
	deps/Module-cpp-logger/src/Logger.cpp
	deps/Module-cpp-logger/src/TIme.cpp
)

target_include_directories(kuchnia-modules PUBLIC
	deps/Module-cpp-config/src
	deps/Module-cpp-logger/src
)

set_target_properties(kuchnia-modules PROPERTIES POSITION_INDEPENDENT_CODE ON)

qt_add_executable(kuchnia
	src/main.cpp
	src/app/AppState.cpp
	src/app/CameraFeed.cpp
	src/app/Cameras.cpp
	src/app/Gate.cpp
	src/app/HotWater.cpp
	src/app/KeyBindings.cpp
	src/app/Panel.cpp
	src/app/People.cpp
	src/app/PeopleModel.cpp
	src/app/Radio.cpp
	src/app/Series.cpp
	src/app/SnapClient.cpp
	src/app/Trace.cpp
	src/app/Volume.cpp
	src/app/Weather.cpp
	src/integrations/Database.cpp
	src/integrations/Http.cpp
	src/integrations/Integrations.cpp
	src/integrations/Location.cpp
	src/integrations/Log.cpp
	src/integrations/Mqtt.cpp
	src/integrations/Rest.cpp
	src/integrations/Service.cpp
	src/integrations/Settings.cpp
)

set(KUCHNIA_QML
	src/qml/Actions.qml
	src/qml/Button.qml
	src/qml/Card.qml
	src/qml/CardFrame.qml
	src/qml/CameraTile.qml
	src/qml/CamerasScreen.qml
	src/qml/Carousel.qml
	src/qml/CarouselIn.qml
	src/qml/CarouselOut.qml
	src/qml/CarouselWeather.qml
	src/qml/Cctv.qml
	src/qml/Cells.qml
	src/qml/ChartCard.qml
	src/qml/Clock.qml
	src/qml/CloudBaseChart.qml
	src/qml/CloudCoverCard.qml
	src/qml/CloudLayersCard.qml
	src/qml/CompactScreen.qml
	src/qml/ConditionsCard.qml
	src/qml/Context.qml
	src/qml/DualAxisChart.qml
	src/qml/ForecastCard.qml
	src/qml/ForecastSpan.qml
	src/qml/GatePanel.qml
	src/qml/Gauge.qml
	src/qml/HotWaterPanel.qml
	src/qml/LineChart.qml
	src/qml/Main.qml
	src/qml/MapPanel.qml
	src/qml/MapScreen.qml
	src/qml/Nav.qml
	src/qml/OverlayChart.qml
	src/qml/PrecipitationCard.qml
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
# so Main.qml would answer to qrc:/qt/qml/Kuchnia/src/qml/Main.qml and the generated
# qmldir would carry this repository's directory layout. It resolves either way; the
# alias is what keeps the module's public shape independent of where the sources sit.
foreach(qml IN LISTS KUCHNIA_QML)
	get_filename_component(name "${qml}" NAME)
	set_source_files_properties("${qml}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
endforeach()

# These seven carry `pragma Singleton`, which is only half of what a singleton needs: without
# this the generated qmldir does not declare it, and every `Theme.`, `Nav.`, `Cells.`,
# `ForecastSpan.`, `Carousel.`, `Cctv.` and `Actions.` in the scene resolves to undefined - an
# unstyled screen with every panel at the origin, which answers no key at all, rather than an
# error.
set_source_files_properties(src/qml/Theme.qml src/qml/Nav.qml src/qml/ForecastSpan.qml
	src/qml/Cells.qml src/qml/Carousel.qml src/qml/Cctv.qml src/qml/Actions.qml
	PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# URI Kuchnia is the string main.cpp passes to loadFromModule() and the one AppState registers
# its singletons under; they are one fact in three places and nothing checks that they agree -
# a mismatch is a runtime "module is not installed" or "is not a type", not a build failure.
qt_add_qml_module(kuchnia
	URI Kuchnia
	VERSION 1.0
	QML_FILES ${KUCHNIA_QML}
)

# A plain resource rather than the QML module's RESOURCES, which would put these under
# :/qt/qml/Kuchnia/. main.cpp opens :/fonts/LiberationSans-Regular.ttf by that name, and
# addApplicationFont() reports a path that does not exist exactly as it reports a corrupt
# font: -1, and a screen with no text on it.
qt_add_resources(kuchnia "fonts"
	PREFIX "/fonts"
	BASE assets/fonts
	FILES
		assets/fonts/LiberationSans-Regular.ttf
		assets/fonts/LiberationSans-Bold.ttf
)

# src/ on the path, so an include reads the same wherever it is written: src/app/ and
# src/integrations/ include each other by their repo-relative names rather than by "../".
target_include_directories(kuchnia PRIVATE src)

target_compile_definitions(kuchnia PRIVATE KUCHNIA_VERSION="${KUCHNIA_VERSION}")

target_link_libraries(kuchnia PRIVATE
	Qt6::Gui
	Qt6::Multimedia
	Qt6::Qml
	Qt6::Quick
	kuchnia-modules
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
install(TARGETS kuchnia RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# The RTSP diagnostic tool, which is not part of the application: it plays the same streams
# through the same VideoOutput with Qt's decoder taken out of the path, to answer whether a
# camera that will not come up is the stream or the backend. See docs/rtsp.md.
#
# OFF by default because debian/rules configures with nothing but its own options - a default
# of ON would build it into every package run, and one install() rule away from shipping it.
option(KUCHNIA_TOOLS "Build the diagnostic tools under tools/" OFF)

if(KUCHNIA_TOOLS)
	add_subdirectory(tools/rtsp-probe)
endif()
