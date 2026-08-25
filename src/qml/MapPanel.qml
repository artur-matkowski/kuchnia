import QtQuick
import QtLocation
import QtPositioning
import Kuchnia

// The map, and everyone on it.
//
// Three things here are silent when they are wrong, and all three look like a working map:
//
// 1. `activeMapType` must be the CustomMap entry. The osm plugin only reaches
//    osm.mapping.custom.host through that map type; left on the default it draws Qt's own
//    hardcoded providers instead, so the wrong tiles arrive with no error anywhere.
//    map-tile-url must also end in a slash - the plugin appends "%z/%x/%y.png" straight
//    onto it, and without one the zoom level is welded to the host name.
// 2. The plugin is given no `providersrepository.address` and told the repository is
//    disabled, so it never calls maps-redirect.qt.io. Enabled, that lookup is an internet
//    dependency at startup that nothing in this repository declares.
// 3. `People.hasBounds` gates the viewport. Four zeroes is a real coordinate in the Gulf of
//    Guinea, and a map framed on empty bounds is not blank - it is confidently wrong.
Card {
	id: root

	title: "Gdzie kto jest"
	status: People.status
	statusDetail: People.statusDetail

	// The ticket's requirement, and it lives here rather than in C++ because it is a property
	// of how the map is framed and not of where anyone is: People publishes the raw extent.
	readonly property real fitPadding: 0.10

	// What the viewport is set to when everyone is in one place - a single person, or a family
	// at one address. Their bounding box has no area at all, and a zero-span region asks the
	// map for infinite zoom: Qt clamps it, but to its own maximum rather than to anything
	// readable, so the street is drawn at a zoom nobody can place.
	readonly property real minimumSpan: 0.01   // degrees, roughly a kilometre of latitude

	// Past this, a marker says how old it is. Nobody is ever dropped for being stale: somebody
	// disappearing off this map has to mean they stopped sharing, and a phone that slept for
	// an afternoon looks exactly like one that is standing still.
	readonly property int staleAfterMs: 15 * 60 * 1000

	// Wall-clock, resampled, because "12 min temu" written once is wrong a minute later and
	// nothing on the row changes to say so - seenAt does not move, only now does. It ticks only
	// while this panel is on screen; SceneElement takes visible away with the context.
	property double now: Date.now()

	Timer {
		interval: 60000
		repeat: true
		running: root.visible
		triggeredOnStart: true    // or the ages are a minute stale every time the map arrives
		onTriggered: root.now = Date.now()
	}

	Plugin {
		id: osm
		name: "osm"

		// Ours, and the only one. See the note above about what happens without these two.
		PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: true }
		PluginParameter { name: "osm.mapping.custom.host"; value: People.tileUrl }
		PluginParameter { name: "osm.useragent"; value: "kuchnia" }
	}

	Map {
		id: map

		anchors {
			left: parent.left
			right: parent.right
			top: parent.top
			bottom: parent.bottom
			topMargin: root.contentTop
			leftMargin: Theme.gap
			rightMargin: Theme.gap
			bottomMargin: Theme.gap
		}

		plugin: osm

		// The board answers keys and has no pointer, so this is a Map and not a MapView: a
		// MapView brings drag and wheel handlers that nothing here can drive, and an item that
		// takes focus starves the single Keys.onPressed in Main.qml - see docs/input.md.
		focus: false

		// Assigned from the signal and NOT bound. The plugin fills supportedMapTypes when its
		// provider answers, and nothing guarantees that has happened by the time a binding
		// here is first evaluated - a binding that runs against an empty list assigns
		// undefined, and it does not run again usefully.
		onSupportedMapTypesChanged: map.selectCustomType()

		// By style rather than by position in the list: the CustomMap is documented as the
		// last entry, but a position is a fact about today's plugin and a style is the thing
		// being asked for. Nothing here falls back to another type - a map drawing somebody
		// else's tiles is the failure this is guarding, so it says so instead.
		function selectCustomType() {
			for (var i = 0; i < map.supportedMapTypes.length; ++i) {
				if (map.supportedMapTypes[i].style === MapType.CustomMap) {
					map.activeMapType = map.supportedMapTypes[i]
					return
				}
			}
			console.warn("no CustomMap among " + map.supportedMapTypes.length +
			             " map types - map-tile-url is not being drawn from")
		}

		// Assigned rather than bound: a binding for visibleRegion has to name visibleRegion
		// on its own right-hand side to say "leave it alone when there is nobody", and that
		// is a binding loop. Set from the one signal that means the extent moved.
		Component.onCompleted: root.frame()

		Connections {
			target: People
			function onBoundsChanged() { root.frame() }
		}

		// The refresh key, answered here rather than in Actions because the tile cache belongs
		// to this Map. clearData() blanks the whole map for a moment - see docs/map.md.
		Connections {
			target: Actions
			function onInvoked(id) {
				if (id !== "map-refresh")
					return
				map.clearData()
				People.refresh()
			}
		}

		MapItemView {
			model: People.model

			delegate: MapQuickItem {
				id: marker

				required property string name
				required property double latitude
				required property double longitude
				required property double seenAt
				required property int battery

				readonly property bool stale: root.now - marker.seenAt > root.staleAfterMs

				coordinate: QtPositioning.coordinate(marker.latitude, marker.longitude)

				// The pin's point, not its corner: anchorPoint is what puts the tip of the
				// marker on the coordinate rather than its top-left, and without it everyone
				// is drawn down and to the right of where they are.
				anchorPoint.x: pin.width / 2
				anchorPoint.y: pin.height

				sourceItem: Column {
					id: pin
					spacing: 2

					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						width: lines.width + Theme.gap * 2
						height: lines.height + Theme.gap
						radius: 4
						color: Theme.surface
						border.color: marker.stale ? Theme.connecting : Theme.accent
						border.width: 2

						Column {
							id: lines
							anchors.centerIn: parent

							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								text: marker.name
								color: Theme.text
								font.pixelSize: Theme.fontLabel
								font.bold: true
							}

							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								visible: text !== ""
								text: root.detailOf(marker.stale ? marker.seenAt : 0,
								                    marker.battery)
								color: Theme.textDim
								font.pixelSize: Theme.fontLabel
							}
						}
					}

					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						width: 10
						height: 10
						radius: 5
						color: marker.stale ? Theme.connecting : Theme.accent
					}
				}
			}
		}
	}

	// The second line under a name: how old the fix is once it is worth saying, and the phone's
	// charge when the service reported one. A seenAt of 0 asks for no age at all.
	//
	// battery is -1 when the service said nothing, which is why this tests for negative rather
	// than for falsy - a phone at 0% is a fact worth drawing and 0 is exactly what a "missing"
	// default would look like.
	function detailOf(seenAt, battery) {
		var parts = []
		if (seenAt > 0)
			parts.push(root.ageOf(root.now - seenAt))
		if (battery >= 0)
			parts.push(battery + "%")
		return parts.join(" \u00b7 ")
	}

	function ageOf(ms) {
		var minutes = Math.round(ms / 60000)
		if (minutes < 60)
			return minutes + " min temu"

		var hours = Math.round(minutes / 60)
		if (hours < 24)
			return hours + " godz. temu"

		var days = Math.round(hours / 24)
		return days === 1 ? "1 dzień temu" : days + " dni temu"
	}

	// Frames everyone, or leaves the viewport alone when there is nobody to frame.
	function frame() {
		if (People.hasBounds)
			map.visibleRegion = root.regionOf()
	}

	// The bounding box, padded, and never narrower than minimumSpan. Built here rather than in
	// C++ so that Qt6::Positioning stays off the link line - People publishes four doubles.
	function regionOf() {
		var latSpan = Math.max(People.maxLatitude - People.minLatitude, root.minimumSpan)
		var lonSpan = Math.max(People.maxLongitude - People.minLongitude, root.minimumSpan)

		var latMid = (People.maxLatitude + People.minLatitude) / 2
		var lonMid = (People.maxLongitude + People.minLongitude) / 2

		var latPad = latSpan * (1 + root.fitPadding) / 2
		var lonPad = lonSpan * (1 + root.fitPadding) / 2

		return QtPositioning.rectangle(
			QtPositioning.coordinate(latMid + latPad, lonMid - lonPad),
			QtPositioning.coordinate(latMid - latPad, lonMid + lonPad))
	}
}
