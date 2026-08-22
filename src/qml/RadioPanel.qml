import QtCore
import QtQuick
import QtQuick.Layouts
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

	// What the station says it is playing. The stations do send it - ICY StreamTitle is in the
	// stream and ffprobe reads it - but Qt's ffmpeg backend maps it onto no metadata key this
	// can read: a playing MP3 station offers Duration, FileFormat, AudioCodec and AudioBitRate
	// and nothing else. So this is empty in practice, and it stays empty rather than being
	// filled with a placeholder - see docs/media.md.
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

		// The stations, and the only way to reach one that is not the next or the previous.
		ListView {
			id: channels

			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true

			model: Radio.names
			currentIndex: Radio.index

			delegate: Rectangle {
				// The view's width and not parent.width: a delegate's parent is the content item,
				// which is as wide as the widest delegate rather than as wide as the view.
				width: channels.width
				height: Theme.fontBody * 2
				color: Radio.index === index ? Theme.accent : "transparent"

				Text {
					anchors { fill: parent; leftMargin: Theme.gap; rightMargin: Theme.gap }
					verticalAlignment: Text.AlignVCenter
					text: modelData
					color: Radio.index === index ? Theme.background : Theme.text
					font.pixelSize: Theme.fontBody
					elide: Text.ElideRight
				}

				MouseArea {
					anchors.fill: parent
					onClicked: Radio.index = index
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
				text: "Prev"
				enabled: Radio.count > 1
				onClicked: Radio.previous()
			}
			Button {
				Layout.fillWidth: true
				Layout.preferredHeight: Theme.fontBody * 2
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
				Layout.fillWidth: true
				Layout.preferredHeight: Theme.fontBody * 2
				text: "Next"
				enabled: Radio.count > 1
				onClicked: Radio.next()
			}
		}
	}
}
