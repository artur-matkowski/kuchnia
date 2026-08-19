import QtQuick
import QtMultimedia

// One RTSP stream.
//
// THREE THINGS THAT FAIL QUIETLY HERE:
//
// The AudioOutput is assigned and muted rather than left off. A MediaPlayer with no
// audioOutput is silent on some backends and audible on others, and the two cameras that
// carry sound are the ones that would prove which - after the radio has already been mixed
// with a doorway.
//
// A stream that goes away does not error once and stay errored: the player settles into
// StoppedState and simply paints its last frame forever, which is a live-looking tile of an
// hour-old picture. The retry below is what makes that impossible, and it backs off so a
// camera that is genuinely gone does not reconnect in a tight loop for days.
//
// Liveness is counted in frames off the video sink. position does not advance on a live
// stream whose duration the container never declares, and playbackState says Playing from
// the moment play() is called - see docs/media.md.
Rectangle {
	id: root

	property string url: ""
	property string label: ""
	property int minimumRetryMs: 1000
	property int maximumRetryMs: 30000

	// How long a playing stream may go without a frame before it is called dead.
	property int stallTimeoutMs: 5000

	// How long a fresh connection may take to produce its first frame. Far longer than the
	// stall budget: an RTSP session that has to fall back from UDP to TCP takes seconds to
	// hand over a picture, and judging it on the stall budget kills every stream on connect.
	property int connectTimeoutMs: 20000

	property int _retryMs: minimumRetryMs
	property string _health: "connecting"
	property string _detail: ""
	property int _frames: 0
	property double _lastProgressMs: 0

	color: "black"
	border.color: Theme.border
	border.width: 1

	function _setHealth(health, detail) {
		if (health === "live")
			root._retryMs = root.minimumRetryMs
		if (root._health === health && root._detail === detail)
			return
		root._health = health
		root._detail = detail
		console.info("[camera] " + root.label + ": " + health + (detail.length > 0 ? " (" + detail + ")" : ""))
	}

	// source is assigned rather than bound. Reconnecting means handing the backend a fresh
	// source, and a stop()/play() pair on the same one makes it seek instead - which on a live
	// stream is a PAUSE the server refuses and a tile that never comes back.
	function _connect() {
		if (root.url.length === 0)
			return
		retry.stop()
		root._frames = 0
		root._lastProgressMs = Date.now()
		root._setHealth("connecting", "")
		// Clearing the source is the reconnect: it tears the session down without a stop(),
		// which the backend turns into a seek and an RTSP PAUSE the server answers with 405.
		player.source = ""
		player.source = root.url
		player.play()
	}

	function _retryLater() {
		retry.interval = root._retryMs
		root._retryMs = Math.min(root._retryMs * 2, root.maximumRetryMs)
		retry.restart()
	}

	MediaPlayer {
		id: player
		videoOutput: output

		// Never unmuted. The radio owns the one audio sink in this application.
		audioOutput: AudioOutput { muted: true }

		onErrorOccurred: function(error, text) {
			root._setHealth("failed", text)
			root._retryLater()
		}

		// A stream that ends is not an error and reports none: the peer closed it, which is
		// what a camera reboot looks like from here. Without this the tile keeps painting its
		// last frame and goes on claiming to be live.
		onMediaStatusChanged: {
			if (mediaStatus === MediaPlayer.EndOfMedia) {
				root._setHealth("connecting", "ended")
				root._retryLater()
			}
		}
	}

	// The only evidence that this stream is feeding us anything.
	Connections {
		target: output.videoSink

		function onVideoFrameChanged(frame) {
			root._frames++
			root._lastProgressMs = Date.now()
			root._setHealth("live", "")
		}
	}

	// THE ONE THAT MATTERS. A camera that is switched off mid-stream does not error and does
	// not end: the demuxer simply stops being fed, playbackState stays Playing, and the tile
	// paints its last frame under a green "live" badge for as long as the process runs.
	Timer {
		id: watchdog
		interval: 1000
		running: root.url.length > 0
		repeat: true
		onTriggered: {
			// A pending reconnect owns the tile. Without this the watchdog re-arms the retry
			// timer on every tick, pushing its deadline out by a tick each time, and the
			// reconnect it is waiting for never happens.
			if (retry.running)
				return
			var budget = root._frames === 0 ? root.connectTimeoutMs : root.stallTimeoutMs
			if (Date.now() - root._lastProgressMs < budget)
				return
			root._setHealth("failed", root._frames === 0 ? "no first frame" : "stalled")
			root._retryLater()
		}
	}

	// onUrlChanged is not also wired up: inside a Repeater the url binding is evaluated during
	// creation and this runs after it, so the two together open every stream twice.
	Component.onCompleted: _connect()

	Timer {
		id: retry
		repeat: false
		onTriggered: root._connect()
	}

	VideoOutput {
		id: output
		anchors.fill: parent
		fillMode: VideoOutput.PreserveAspectFit
	}

	// Over the picture, not beside it: a tile whose stream died keeps painting its last frame
	// and the badge is the only thing that says the frame is old.
	Rectangle {
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: 20
		color: "#c0000000"

		Text {
			anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
			text: root.label
			color: Theme.text
			font.pixelSize: 11
		}

		StatusBadge {
			anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
			health: root._health
			detail: root._detail
		}
	}

	Text {
		anchors.centerIn: parent
		visible: root.url.length === 0
		text: "no camera-url"
		color: Theme.textDim
		font.pixelSize: 12
	}
}
