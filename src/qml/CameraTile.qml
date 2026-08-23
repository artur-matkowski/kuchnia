import QtQuick
import QtMultimedia
import QtHmi

// One RTSP stream.
//
// FOUR THINGS THAT FAIL QUIETLY HERE:
//
// The AudioOutput is assigned on every tile whether or not it is wanted, and muted when it is
// not. A MediaPlayer with no audioOutput is silent on some backends and audible on others, and
// the two cameras that carry sound are the ones that would prove which - after the radio has
// already been mixed with a doorway.
//
// A stream that goes away does not error once and stay errored: the player settles into
// StoppedState and simply paints its last frame forever, which is a live-looking tile of an
// hour-old picture. The retry below is what makes that impossible, and it backs off so a
// camera that is genuinely gone does not reconnect in a tight loop for days.
//
// Liveness is counted in frames off the video sink. position does not advance on a live
// stream whose duration the container never declares, and playbackState says Playing from
// the moment play() is called - see docs/media.md.
//
// And source is not a setter. Assigning it waits for any open already in flight, on the
// thread doing the assigning, which is the one drawing the screen. Nothing below touches
// source while _loading - see docs/app.md.
Rectangle {
	id: root

	property string url: ""
	property string label: ""

	// Whether this tile is wanted on screen. Going false does not disconnect immediately -
	// see holdMs.
	property bool active: true

	// Whether this tile may be heard. Who decides is Cctv, and the caller passes the answer in:
	// a tile knows which camera it is and nothing else.
	property bool audible: false

	// How long the stream survives after active goes false, and NEGATIVE never disconnects.
	//
	// It is not a pause. A live RTSP session cannot be paused - the PAUSE is answered with 405
	// and the tile never comes back - so the only way to stop decoding is to tear the session
	// down and open a fresh one, which these cameras answer in five to six seconds. That is
	// the number the hold is weighed against: short enough and every glance at another context
	// costs six seconds of black tiles on the way back.
	property int holdMs: Cameras.holdMs
	property int minimumRetryMs: 1000
	property int maximumRetryMs: 30000

	// How long a playing stream may go without a frame before it is called dead.
	property int stallTimeoutMs: 5000

	// How long a fresh connection may take to produce its first frame. Far longer than the
	// stall budget: an RTSP session that has to fall back from UDP to TCP takes seconds to
	// hand over a picture, and judging it on the stall budget kills every stream on connect.
	property int connectTimeoutMs: 20000

	// Whether the backend is inside an open of its own. Assigning source now waits for that
	// open on the GUI thread, and runs it here outright if the pool has not started it yet -
	// docs/app.md. Everything below defers instead of interrupting.
	readonly property bool _loading: player.mediaStatus === MediaPlayer.LoadingMedia

	property int _retryMs: minimumRetryMs
	property string _health: "connecting"
	property string _detail: ""
	property int _frames: 0
	property double _lastProgressMs: 0
	property bool _down: false

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
		// The backend is already opening this stream, and there is nothing to gain by handing it
		// another source: an open that fails says so, and that lands on onErrorOccurred. Arriving
		// here while torn down is a tile that came back mid-open - keep the open, and cancel the
		// teardown onMediaStatusChanged is holding.
		if (root._loading) {
			root._down = false
			return
		}
		retry.stop()
		hold.stop()
		root._down = false
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
		// A torn-down tile schedules nothing. Clearing the source is itself reported as
		// EndOfMedia, so without this the teardown arms a retry that reopens the stream while
		// the context is off screen - the decoder this was meant to stop, running anyway.
		if (root._down)
			return
		retry.interval = root._retryMs
		root._retryMs = Math.min(root._retryMs * 2, root.maximumRetryMs)
		retry.restart()
	}

	MediaPlayer {
		id: player
		videoOutput: output

		// The sink is shared with the radio, which wins. Muted here rather than by leaving the
		// output unassigned - see the note at the top and docs/media.md.
		audioOutput: AudioOutput { muted: !root.audible }

		onErrorOccurred: function(error, text) {
			root._setHealth("failed", text)
			root._retryLater()
		}

		// A stream that ends is not an error and reports none: the peer closed it, which is
		// what a camera reboot looks like from here. Without this the tile keeps painting its
		// last frame and goes on claiming to be live.
		onMediaStatusChanged: {
			// Every status change is the backend saying it got somewhere, and the connect budget
			// is measured from the last one. Without this an open that legitimately takes longer
			// than connectTimeoutMs is judged on a clock that started before it.
			root._lastProgressMs = Date.now()

			// The teardown the hold timer could not perform while an open was in flight. Clearing
			// the source is itself a status change, and the source check is what stops this from
			// recursing on its own work.
			if (root._down) {
				if (!root._loading && player.source.toString().length > 0)
					player.source = ""
				return
			}

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
		// Not while torn down, or a tile that was asked to stop is reported stalled and
		// starts the retry backoff climbing while nothing is looking at it.
		running: root.url.length > 0 && !root._down
		repeat: true
		onTriggered: {
			// The backend owns the tile while it is opening. It carries its own timeouts and
			// reports its own failure, and taking the stream off it from here costs the whole
			// screen - docs/app.md. Say so instead: an open that never lands is a tile that will
			// never retry, and it otherwise reads exactly like one that is about to.
			if (root._loading) {
				if (Date.now() - root._lastProgressMs >= root.connectTimeoutMs)
					root._setHealth("connecting", "still opening")
				return
			}

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

	onActiveChanged: {
		if (root.active) {
			hold.stop()
			// Only reconnect if the hold actually expired. Coming back inside it means the
			// stream never stopped, which is the whole point of the hold.
			if (root._down)
				root._connect()
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
		onTriggered: {
			retry.stop()
			root._down = true
			// Not while an open is in flight: clearing the source waits for it here, and the
			// screen stops with it. onMediaStatusChanged finishes the teardown when it lands.
			if (!root._loading)
				player.source = ""
			root._frames = 0
			root._setHealth("connecting", "off screen")
		}
	}

	// onUrlChanged is not also wired up: inside a Repeater the url binding is evaluated during
	// creation and this runs after it, so the two together open every stream twice.
	Component.onCompleted: if (root.active) _connect()

	Timer {
		id: retry
		repeat: false
		onTriggered: root._connect()
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
			health: root._health
			detail: root._detail
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
