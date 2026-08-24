import QtQuick
import QtQuick.Window
import QtMultimedia

// Both backends draw through this one file, so the only thing that differs between a run of
// `--backend qt` and a run of `--backend ffmpeg` is where the frames came from. The window,
// the VideoOutput, the fillMode and the scene graph are the same object either way.
Window {
	id: root

	readonly property int count: Math.max(feeds.length, 1)
	readonly property int columns: Math.ceil(Math.sqrt(root.count))
	readonly property int rows: Math.ceil(root.count / root.columns)

	width: 1366
	height: 768
	visibility: wantFullscreen ? Window.FullScreen : Window.Windowed
	color: "black"
	title: "rtsp-probe [" + backend + "]"

	Grid {
		anchors.fill: parent
		columns: root.columns

		Repeater {
			model: feeds

			delegate: Rectangle {
				id: tile

				required property var modelData

				width: root.width / root.columns
				height: root.height / root.rows
				color: "black"
				border.color: "#303030"
				border.width: 1

				VideoOutput {
					id: output
					anchors.fill: parent
					// Stretch, as CameraTile does: a black bar down one tile of several reads
					// as a tile that has stopped working.
					fillMode: VideoOutput.Stretch
				}

				// The sink is CONSTANT on VideoOutput and cannot be assigned, so the scene hands
				// it over rather than the feed taking one. Both backends, because this is also
				// where frames are counted - under `qt` the feed only listens to the sink, and
				// the MediaPlayer below is what writes to it.
				Component.onCompleted: tile.modelData.attach(output.videoSink)

				// Constructed only under `qt`. Importing QtMultimedia already loads the media
				// backend either way - VideoOutput comes out of it - so libav is in the process
				// whichever backend is chosen. What `ffmpeg` removes is Qt USING it: with no
				// MediaPlayer, nothing of Qt's opens the URL, demuxes it or decodes it.
				Loader {
					active: backend === "qt"

					sourceComponent: Item {
						MediaPlayer {
							id: player
							videoOutput: output
							// Assigned, never left unset: unset is silent on some backends and
							// audible on others - docs/media.md.
							audioOutput: AudioOutput { muted: true }
							source: tile.modelData.url
							// The clock starts where the stream is asked for, so the number is
							// comparable with the ffmpeg backend's.
							Component.onCompleted: { tile.modelData.noteAsked(); player.play() }
							onErrorOccurred: function(error, text) {
								console.info("[feed] " + tile.modelData.label + ": failed (" + text + ")")
							}
						}

						// What the player believes about itself, which on a stalled RTSP stream is
						// the only thing that distinguishes "opening" from "opened and silent" -
						// neither of which reports itself. docs/media.md.
						Timer {
							interval: 2000
							repeat: true
							running: true
							onTriggered: console.info("[qt] " + tile.modelData.label
								+ " playback=" + player.playbackState
								+ " status=" + player.mediaStatus
								+ " pos=" + player.position
								+ " frames=" + tile.modelData.frames
								+ " err=" + player.error
								+ (player.errorString.length > 0 ? " " + player.errorString : ""))
						}
					}
				}

				// Both backends, so two runs produce logs that can be read against each other.
				// The [qt] line inside the Loader adds what only a MediaPlayer can be asked.
				Timer {
					interval: 5000
					repeat: true
					running: true
					onTriggered: console.info("[tile] " + tile.modelData.label
						+ " health=" + tile.modelData.health
						+ " frames=" + tile.modelData.frames)
				}

				Rectangle {
					anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
					height: 26
					color: "#c0000000"

					Text {
						anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
						text: tile.modelData.label
						color: "#e0e0e0"
						font.pixelSize: 14
					}

					Text {
						anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
						text: tile.modelData.health
						      + (tile.modelData.detail.length > 0 ? " - " + tile.modelData.detail : "")
						      + "  " + tile.modelData.frames + "f"
						color: tile.modelData.health === "live" ? "#4caf50"
						     : tile.modelData.health === "failed" ? "#f44336" : "#ffb300"
						font.pixelSize: 14
					}
				}
			}
		}
	}
}
