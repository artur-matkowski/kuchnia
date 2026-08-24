import QtCore
import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Kuchnia

// The internet radio. It shares one audio sink with the cameras and wins whenever it is
// playing, which is what the Binding below publishes.
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
	Component.onCompleted: {
		Radio.index = persisted.station
		root._station()
	}
	Connections {
		target: Radio
		function onIndexChanged() {
			persisted.station = Radio.index
			root._station()
		}
	}

	property bool _stationPending: false

	// What points the player at a station, instead of a binding onto Radio.url. Assigning
	// source waits for whatever the player is already opening, on the GUI thread - so a
	// station changed while one is being opened stops the whole screen until it answers, and
	// a stream the pool has not started yet is opened here outright. See docs/app.md.
	function _station() {
		root._stationPending = false
		if (player.source.toString() === Radio.url)
			return
		if (player.mediaStatus === MediaPlayer.LoadingMedia) {
			root._stationPending = true
			return
		}
		Trace.begin("radio.source")
		player.source = Radio.url
		Trace.end("radio.source")
	}

	MediaPlayer {
		id: player
		audioOutput: AudioOutput {}

		// A source change while playing does not restart playback by itself.
		onSourceChanged: if (root._wanted && source.toString().length > 0) play()

		// A station that arrived while this one was still being opened.
		onMediaStatusChanged: if (root._stationPending) root._station()

		onErrorOccurred: function(error, text) { root._detail = text }
		onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) root._detail = ""
	}

	property bool _wanted: false
	property string _detail: ""

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
		if (root._wanted)
			player.play()
		else
			player.stop()
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
	readonly property string _nowPlaying:
		player.metaData ? (player.metaData.stringValue(MediaMetaData.Title) || "") : ""

	status: player.playbackState === MediaPlayer.PlayingState ? "live"
	      : _detail.length > 0 ? "failed"
	      : _wanted ? "connecting" : ""
	statusDetail: _detail

	ColumnLayout {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			Layout.fillWidth: true
			text: Radio.count === 0 ? "no stations in " + Radio.playlist
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
