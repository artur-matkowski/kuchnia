import QtQuick
import QtMultimedia

// One RTSP stream.
//
// TWO THINGS THAT FAIL QUIETLY HERE:
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
Rectangle {
	id: root

	property string url: ""
	property string label: ""
	property int minimumRetryMs: 1000
	property int maximumRetryMs: 30000

	// How long a playing stream may go without advancing before it is called dead.
	property int stallTimeoutMs: 5000

	property int _retryMs: minimumRetryMs
	property string _health: "connecting"
	property string _detail: ""
	property int _lastPosition: -1

	color: "black"
	border.color: Theme.border
	border.width: 1

	// source is assigned rather than bound. Reconnecting means handing the backend a fresh
	// source, and a stop()/play() pair on the same one makes it seek instead - which on a live
	// stream is a PAUSE the server refuses and a tile that never comes back.
	function _connect() {
		if (root.url.length === 0)
			return
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
			root._health = "failed"
			root._detail = text
			root._retryLater()
		}

		onPlaybackStateChanged: {
			if (playbackState === MediaPlayer.PlayingState) {
				root._health = "live"
				root._detail = ""
				root._retryMs = root.minimumRetryMs
			}
		}

		// A stream that ends is not an error and reports none: the peer closed it, which is
		// what a camera reboot looks like from here. Without this the tile keeps painting its
		// last frame and goes on claiming to be live.
		onMediaStatusChanged: {
			if (mediaStatus === MediaPlayer.EndOfMedia) {
				if (root._health === "live")
					root._health = "connecting"
				root._retryLater()
			}
		}
	}

	// THE ONE THAT MATTERS. A camera that is switched off mid-stream does not error and does
	// not end: the demuxer simply stops being fed, playbackState stays Playing, and the tile
	// paints its last frame under a green "live" badge for as long as the process runs. The
	// only thing that changes is that position stops advancing.
	Timer {
		id: watchdog
		interval: root.stallTimeoutMs
		running: true
		repeat: true
		onTriggered: {
			if (player.playbackState !== MediaPlayer.PlayingState) {
				root._lastPosition = -1
				return
			}
			if (player.position === root._lastPosition) {
				root._health = "failed"
				root._detail = "stalled"
				root._retryLater()
			}
			root._lastPosition = player.position
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
