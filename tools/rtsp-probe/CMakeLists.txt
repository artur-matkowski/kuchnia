# Qt6::Multimedia is linked for QVideoSink and QVideoFrame - the presentation half - and for
# the MediaPlayer the `qt` backend builds. Importing QtMultimedia loads the media backend
# either way, so libav is in the process whichever backend is chosen; what `ffmpeg` removes is
# Qt using it.
#
# CameraFeed is the application's own decode path, compiled in rather than copied: one
# implementation of the pipe slicing, so a fix to the tool is a fix to the panel. The tool
# does not link the kuchnia target - it is an executable, not a library - so the source is
# named directly and src/ goes on the include path below.
qt_add_executable(rtsp-probe
	main.cpp
	${CMAKE_SOURCE_DIR}/src/app/CameraFeed.cpp
	${CMAKE_SOURCE_DIR}/src/integrations/Log.cpp
)

target_include_directories(rtsp-probe PRIVATE ${CMAKE_SOURCE_DIR}/src)

qt_add_qml_module(rtsp-probe
	URI RtspProbe
	VERSION 1.0
	QML_FILES Probe.qml
)

target_link_libraries(rtsp-probe PRIVATE
	Qt6::Gui
	Qt6::Multimedia
	Qt6::Qml
	Qt6::Quick
	# CameraFeed logs through applog, which is Module-cpp-logger.
	kuchnia-modules
)

# Beside kuchnia rather than three directories under it: the two are run one after the other
# and a capture names the binary it measured.
set_target_properties(rtsp-probe PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# No install() rule, and that is the whole reason this builds at all. debian/rules runs a
# plain `dh --buildsystem=cmake`, so anything installed here would land in the .deb.
