# Qt6::Multimedia is linked for QVideoSink and QVideoFrame - the presentation half - and for
# the MediaPlayer the `qt` backend builds. The `ffmpeg` backend uses neither: it runs ffmpeg
# as a child process, so nothing of libav is linked here or loaded into this address space.
qt_add_executable(rtsp-probe
	main.cpp
	Feed.cpp
	Feed.hpp
)

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
)

# Beside kuchnia rather than three directories under it: the two are run one after the other
# and a capture names the binary it measured.
set_target_properties(rtsp-probe PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# No install() rule, and that is the whole reason this builds at all. debian/rules runs a
# plain `dh --buildsystem=cmake`, so anything installed here would land in the .deb.
