import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtHmi

// The whole scene, laid out to be legible rather than to be right: this arrangement exists so
// that every pipe can be seen carrying data at once, and the real layout is a later pass.
Window {
	id: root

	// eglfs ignores this and takes the whole connector. It is the window size on a
	// desktop, and on both targets the aspect the scene is composed against.
	width: 1280
	height: 720
	visible: true
	color: Theme.background
	title: "qt-qml-hmi"

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: Theme.gap
		spacing: Theme.gap

		RowLayout {
			Layout.fillWidth: true
			// Explicit, because Layout.fillHeight defaults to TRUE for a nested layout and
			// only to false for a plain Item - left alone, this row and the camera row below
			// take the whole column and the two panels at the bottom are laid out one pixel
			// high, which reads as a rendering fault rather than a layout one.
			Layout.fillHeight: false
			spacing: Theme.gap

			Clock {}

			Item { Layout.fillWidth: true }

			GatePanel {
				Layout.preferredWidth: 280
				Layout.preferredHeight: 130
			}

			RadioPanel {
				Layout.preferredWidth: 320
				Layout.preferredHeight: 130
			}
		}

		// One tile per camera-url. No fixed count anywhere: an empty list draws no tiles, and
		// the message in the panel below is what says the list is empty.
		RowLayout {
			Layout.fillWidth: true
			Layout.fillHeight: false
			Layout.preferredHeight: 220
			spacing: Theme.gap

			Repeater {
				model: Cameras.urls

				CameraTile {
					Layout.fillWidth: true
					Layout.fillHeight: true
					url: modelData
					label: "camera " + (index + 1)
				}
			}

			Text {
				visible: Cameras.urls.length === 0
				Layout.fillWidth: true
				text: "no camera-url configured"
				color: Theme.textDim
				horizontalAlignment: Text.AlignHCenter
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.fillHeight: true
			spacing: Theme.gap

			HotWaterPanel {
				Layout.fillWidth: true
				Layout.fillHeight: true
			}

			WeatherPanel {
				Layout.fillWidth: true
				Layout.fillHeight: true
			}
		}
	}
}
