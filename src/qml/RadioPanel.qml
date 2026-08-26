import QtCore
import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Kuchnia

// The radio, over either of two transports: a URL station through the MediaPlayer below, and a
// snapcast:// one through a snapclient child. It shares one audio sink with the cameras and
// wins whenever it is playing, which is what the Binding below publishes.
Card {
	id: root

	title: "Radio"

	Settings {
		id: persisted
		// Written to the platform's config location, which the target has to provide - see
		// docs/radio.md. Where it cannot be written the station simply does not survive a
		// restart; nothing else breaks.
		property int station: 0
	}

	// One direction each way, and neither is a binding: a two-way binding between this and
	// Radio.index would fight itself the first time a button moved the station.
	Component.onCompleted: Radio.index = persisted.station
	Connections {
		target: Radio
		function onIndexChanged() {
			persisted.station = Radio.index
			root._apply()
		}

		// A reload left the station that was playing in none of the playlists. Cleared here and
		// applied by the onIndexChanged that follows it, so the transport is released rather than
		// re-opened onto whatever the clamped index now points at.
		function onStationLost() {
			root._wanted = false
			root._detail = ""
		}
	}

	property bool _wanted: false
	property string _detail: ""

	// A source assignment that was held off while the player was opening one.
	property bool _pending: false

	// Which transport this station is played by. The scheme decides, in one place - this is
	// not a fallback beside a working path. See docs/radio.md.
	readonly property bool _synced: SnapClient.handles(Radio.url)

	// Both transports are reconciled with _wanted here and nowhere else, and exactly one of
	// them is ever running. Stopped means no source at all: these are live streams, and a
	// player that keeps its connection resumes behind the broadcast. Idempotent, so the
	// deferral below is a second call and nothing more - SnapClient.play() is idempotent for
	// the same reason.
	//
	// Assigning source waits for whatever the player is already opening, on the GUI thread, so
	// an assignment made while one is in flight would stop the whole screen. See docs/app.md.
	function _apply() {
		root._pending = false

		// Whichever transport this station is not, released first. Before the source goes, so
		// the sink is let go whether or not the drop is deferred.
		if (!root._wanted || !root._synced)
			SnapClient.stop()
		if (!root._wanted || root._synced)
			player.stop()

		// A snapcast station holds no source at all: the player is not its transport, and a
		// URL left on it would be reopened by the next status change.
		const want = (root._wanted && !root._synced) ? Radio.url : ""
		if (player.source.toString() !== want) {
			if (player.mediaStatus === MediaPlayer.LoadingMedia) {
				root._pending = true
				return
			}
			Trace.begin("radio.source")
			player.source = want
			Trace.end("radio.source")
		}

		if (!root._wanted)
			return
		if (root._synced)
			SnapClient.play(Radio.url)
		else
			player.play()
	}

	MediaPlayer {
		id: player
		audioOutput: AudioOutput {}

		// The assignment that was held off, once the open it was waiting on has landed.
		onMediaStatusChanged: if (root._pending) root._apply()

		onErrorOccurred: function(error, text) { root._detail = text }
		onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) root._detail = ""
	}

	// The cameras have to know, because the sink is one and this panel owns it. What was ASKED
	// for and not what the player is doing: a station that drops mid-song would otherwise let a
	// camera into the room until it reconnected. See docs/radio.md.
	Binding { target: Cctv; property: "radioPlaying"; value: root._wanted }

	// The transport, from the button below and from a bound key alike. It is here and not in
	// Actions.qml because what is playing is this MediaPlayer's business and not a singleton's;
	// this panel is instantiated at startup and never destroyed, so a key pressed on the camera
	// screen reaches it. See docs/input.md.
	function _toggle() {
		if (Radio.count === 0)
			return
		root._wanted = !root._wanted
		root._detail = ""
		root._apply()
	}

	Connections {
		target: Actions
		function onInvoked(id) {
			if (id === "radio-play-stop")
				root._toggle()
			else if (id === "radio-next")
				Radio.next()
			else if (id === "radio-previous")
				Radio.previous()
		}
	}

	// What the station says it is playing. The stations do send it - ICY StreamTitle is in the
	// stream and ffprobe reads it - but Qt's ffmpeg backend maps it onto no metadata key this
	// can read: a playing MP3 station offers Duration, FileFormat, AudioCodec and AudioBitRate
	// and nothing else. So this is empty in practice, and it stays empty rather than being
	// filled with a placeholder - see docs/radio.md.
	// Empty on a snapcast station too, and for a second reason: the title is on snapcast's
	// control port, which is a network client this panel does not have.
	readonly property string _nowPlaying: root._synced ? ""
	      : player.metaData ? (player.metaData.stringValue(MediaMetaData.Title) || "") : ""

	// SnapClient starts out "connecting" and stays there between stations, so its status is
	// only asked for while something has actually been asked of it - the card is blank when
	// stopped, exactly as it is on a URL station.
	status: _synced ? (_wanted ? SnapClient.status : "")
	      : player.playbackState === MediaPlayer.PlayingState ? "live"
	      : _detail.length > 0 ? "failed"
	      : _wanted ? "connecting" : ""
	statusDetail: _synced ? (_wanted ? SnapClient.statusDetail : "") : _detail

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			Layout.fillWidth: true
			text: Radio.count === 0 ? "no stations in " + Radio.playlists.join(", ")
			                        : (Radio.index + 1) + "/" + Radio.count + "  " + Radio.name
			color: Radio.count === 0 ? Theme.textDim : Theme.text
			font.pixelSize: Theme.fontReading
			font.bold: true
			elide: Text.ElideRight
		}

		Text {
			Layout.fillWidth: true
			text: root._nowPlaying
			color: Theme.textDim
			font.pixelSize: Theme.fontBody
			elide: Text.ElideRight
		}

		// The stations, and the only way to reach one that is not the next or the previous. The
		// frame is its own Rectangle because a ListView is not one: the list needs an edge of its
		// own to separate a scrolled stop from the card it sits in.
		Rectangle {
			Layout.fillWidth: true
			// Explicit, because it defaults to true for a nested layout and to false for a plain
			// Item - which this is.
			Layout.fillHeight: true

			color: "transparent"
			border.color: Theme.border
			border.width: 1
			radius: 4

			ListView {
				id: channels

				anchors.fill: parent
				anchors.margins: 1
				clip: true

				model: Radio.names
				currentIndex: Radio.index

				delegate: Rectangle {
					// The view's width and not parent.width: a delegate's parent is the content item,
					// which is as wide as the widest delegate rather than as wide as the view.
					width: channels.width
					height: Theme.fontBody * 2
					color: Radio.index === index ? Theme.highlight : "transparent"

					Text {
						anchors { fill: parent; leftMargin: Theme.gap; rightMargin: Theme.gap }
						verticalAlignment: Text.AlignVCenter
						text: modelData
						color: Radio.index === index ? Theme.accent : Theme.text
						font.pixelSize: Theme.fontBody
						elide: Text.ElideRight
					}

					MouseArea {
						anchors.fill: parent
						onClicked: Radio.index = index
					}
				}
			}
		}

		RowLayout {
			Layout.fillWidth: true
			// Explicit, because it defaults to true for a nested layout: left alone the buttons
			// take the whole column and the station list above them is laid out one pixel high.
			Layout.fillHeight: false
			spacing: Theme.gap

			Button {
				Layout.fillWidth: true
				Layout.preferredHeight: Theme.fontBody * 2
				text: "Poprz."
				enabled: Radio.count > 1
				onClicked: Radio.previous()
			}
			Button {
				Layout.fillWidth: true
				Layout.preferredHeight: Theme.fontBody * 2
				text: root._wanted ? "Stop" : "Graj"
				enabled: Radio.count > 0
				onClicked: root._toggle()
			}
			Button {
				Layout.fillWidth: true
				Layout.preferredHeight: Theme.fontBody * 2
				text: "Nast."
				enabled: Radio.count > 1
				onClicked: Radio.next()
			}
		}
	}
}
