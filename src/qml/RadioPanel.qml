import QtCore
import QtQuick
import QtMultimedia
import QtHmi

// The internet radio, and the only thing in this application with an unmuted audio output.
Card {
	id: root

	title: "Radio"

	Settings {
		id: persisted
		// Written to the platform's config location, which the target has to provide - see
		// docs/media.md. Where it cannot be written the station simply does not survive a
		// restart; nothing else breaks.
		property int station: 0
	}

	// One direction each way, and neither is a binding: a two-way binding between this and
	// Radio.index would fight itself the first time a button moved the station.
	Component.onCompleted: Radio.index = persisted.station
	Connections {
		target: Radio
		function onIndexChanged() { persisted.station = Radio.index }
	}

	MediaPlayer {
		id: player
		source: Radio.url
		audioOutput: AudioOutput {}

		// A source change while playing does not restart playback by itself.
		onSourceChanged: if (root._wanted && source.toString().length > 0) play()

		onErrorOccurred: function(error, text) { root._detail = text }
		onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) root._detail = ""
	}

	property bool _wanted: false
	property string _detail: ""

	status: player.playbackState === MediaPlayer.PlayingState ? "live"
	      : _detail.length > 0 ? "failed"
	      : _wanted ? "connecting" : ""
	statusDetail: _detail

	Column {
		anchors { fill: parent; margins: Theme.gap; topMargin: root.contentTop }
		spacing: Theme.gap

		Text {
			text: Radio.count === 0 ? "no radio-url configured"
			                        : (Radio.index + 1) + "/" + Radio.count + "  " + Radio.name
			color: Radio.count === 0 ? Theme.textDim : Theme.text
			font.pixelSize: 14
			width: parent.width
			elide: Text.ElideRight
		}

		Text {
			text: Radio.url
			color: Theme.textDim
			font.pixelSize: 10
			width: parent.width
			elide: Text.ElideMiddle
		}

		Row {
			spacing: Theme.gap

			Button {
				text: "Prev"
				enabled: Radio.count > 1
				onClicked: Radio.previous()
			}
			Button {
				text: root._wanted ? "Stop" : "Play"
				enabled: Radio.count > 0
				onClicked: {
					root._wanted = !root._wanted
					root._detail = ""
					if (root._wanted)
						player.play()
					else
						player.stop()
				}
			}
			Button {
				text: "Next"
				enabled: Radio.count > 1
				onClicked: Radio.next()
			}
		}
	}
}
