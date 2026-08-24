import QtQuick
import QtMultimedia
import Kuchnia

// One RTSP stream. The decoding is `CameraFeed`'s and happens in an ffmpeg child process;
// everything Qt does here is blit the frames it is handed - see docs/media.md.
//
// WHAT FAILS QUIETLY HERE: the hold below. A tile that goes off screen keeps decoding until
// the timer expires, and `holdMs` negative never stops at all - a decoder running for a
// context nobody is looking at, which costs exactly as much as one that is.
Rectangle {
	id: root

	property string url: ""
	property string label: ""

	// Whether this tile is wanted on screen. Going false does not stop the stream
	// immediately - see holdMs.
	property bool active: true

	// Whether this tile may be heard. Who decides is Cctv, and the caller passes the answer in:
	// a tile knows which camera it is and nothing else. There is no mute - the feed opens a
	// second, short-lived stream for the sound and kills it when this goes false.
	property bool audible: false

	// How long the stream survives after active goes false, and NEGATIVE never stops it.
	// Reopening one of these costs two to three seconds, so a glance at another screen is
	// worth holding through and only a real stay is worth paying for.
	property int holdMs: Cameras.holdMs

	color: "black"
	border.color: Theme.border
	border.width: 1

	CameraFeed {
		id: feed
		url: root.url
		label: root.label
		transport: Cameras.transport
		audible: root.audible
	}

	VideoOutput {
		id: output
		anchors.fill: parent
		// The cells are cut to the streams' own 16:9, so a 16:9 camera is neither stretched nor
		// cropped. One that is not fills the cell anyway: a black bar down one tile of five is
		// read as a tile that has stopped working, and the whole frame distorted is read as a
		// wrong lens - which is the cheaper mistake, because it is the tile that still shows
		// everything the camera can see.
		fillMode: VideoOutput.Stretch
	}

	// attach() before start(), and both here rather than in a binding: VideoOutput.videoSink is
	// CONSTANT and cannot be assigned, so the sink is handed over instead - and a feed started
	// before it has one decodes frames with nowhere to put them.
	Component.onCompleted: {
		feed.attach(output.videoSink)
		if (root.active)
			feed.start()
	}

	onActiveChanged: {
		if (root.active) {
			hold.stop()
			// Idempotent. Coming back inside the hold means the stream never stopped, which is
			// the whole point of the hold.
			feed.start()
			return
		}
		if (root.holdMs < 0)
			return
		hold.restart()
	}

	Timer {
		id: hold
		interval: Math.max(root.holdMs, 0)
		repeat: false
		onTriggered: feed.stop("off screen")
	}

	// Over the picture, not beside it: a tile whose stream died keeps painting its last frame
	// and the badge is the only thing that says the frame is old.
	Rectangle {
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: Theme.fontLabel + 10
		color: "#c0000000"

		Text {
			anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
			text: root.label
			color: Theme.text
			font.pixelSize: Theme.fontLabel
		}

		StatusBadge {
			anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
			health: feed.health
			detail: feed.detail
		}
	}

	Text {
		anchors.centerIn: parent
		visible: root.url.length === 0
		text: "no camera-url"
		color: Theme.textDim
		font.pixelSize: Theme.fontBody
	}
}
