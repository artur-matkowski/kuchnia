import QtQuick
import QtLocation
import QtPositioning
import Kuchnia

// The map, everyone on it, and the list that picks one of them.
//
// Everything here that is silent when it is wrong looks like a working map: the plugin's four
// settings, the bounds gate - four zeroes is a real coordinate in the Gulf of Guinea - and what
// the viewport is not allowed to forget between polls. All of it is docs/whereabouts.md.
Card {
	id: root

	title: root.followName.length > 0
	     ? "Gdzie kto jest · " + root.followName
	     : "Gdzie kto jest"
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

	// Where the viewport is taken when it is following one person. A zoom level and not a span,
	// because a span has to go through visibleRegion, which is one assignment that moves the
	// centre and the zoom together and cannot be eased.
	readonly property real followZoom: 16      // street scale: about three kilometres across

	// One duration for both eases. Walking to another person moves the centre and the zoom
	// together, and two durations there read as two separate movements rather than one.
	readonly property int easeMs: 420

	// Past this a marker turns amber; its age is drawn either way. Nobody is ever dropped for
	// being stale: somebody disappearing off this map has to mean they stopped sharing, and a
	// phone that slept for an afternoon looks exactly like one that is standing still.
	readonly property int staleAfterMs: 15 * 60 * 1000

	// The person the viewport is following, by id and never by row: a removal shifts every row
	// below it, so an index held across a poll is a different person with nothing to say so.
	// Empty is everyone, which is the `Wszyscy` row at the top of the list.
	property string followId: ""

	// Their name, written by frame() on every one of its paths and drawn in the title. It is the
	// only evidence, with the list shut, that the map is showing one person rather than all of
	// them.
	property string followName: ""

	// Whether the roster list is out.
	property bool listOpen: false

	// Whether a zoom key has been used. boundsChanged fires on EVERY poll, so a frame() that
	// always wrote the zoom would take one back within people-interval-ms - a zoom key that
	// works and then quietly stops having worked. While this is set a poll moves the centre and
	// leaves the zoom where somebody put it. It is a hold and not a mode: holdZoom() is its one
	// writer, and what keeps it and what drops it is docs/whereabouts.md.
	property bool zoomed: false

	// How long that hold lasts, counted from the last zoom key. Not staleAfterMs, which is the
	// same number about a different thing.
	readonly property int zoomHoldMs: 15 * 60 * 1000

	// The zoom the keys are steering toward, which is NOT map.zoomLevel: read back mid-ease that
	// is wherever the animation has reached, so three quick presses would add less than three
	// levels. One writer, zoom(), which is also where it is clamped.
	property real zoomTarget: 0

	// Whether anything has been framed yet, which is what the pan animation waits for. A Map
	// starts at 0,0.
	property bool framed: false

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

	// The hold's lifetime. Deliberately not gated on root.visible, unlike the timer above: a
	// hold left behind on the way out of the map has to lapse while the context is away, or the
	// map comes back hours later still parked where a key put it.
	Timer {
		id: zoomHold
		interval: root.zoomHoldMs
		onTriggered: {
			root.holdZoom(false)
			root.frame()          // or nothing takes the framing back until the next poll
		}
	}

	Plugin {
		id: osm
		name: "osm"

		// Ours, and the only one. Neither of these is optional - docs/whereabouts.md.
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

		// CoordinateAnimation and not NumberAnimation: a coordinate is not a number, and what
		// that looks like is a pan that snaps with nothing said anywhere. Both Behaviors are
		// held off until something has been framed, or the first fix is a sweep from 0,0 and
		// from the plugin's default zoom.
		//
		// onFinished and not onStopped: a Behavior retargeted mid-flight STOPS its animation
		// rather than finishing it, so walking the list fast prefetches once, when it settles,
		// and not once per key press. prefetchData() is the only prefetch hook QtLocation gives
		// QML and nothing else in the scene calls it - see docs/whereabouts.md.
		Behavior on center {
			enabled: root.framed
			CoordinateAnimation {
				duration: root.easeMs
				easing.type: Easing.InOutCubic
				onFinished: map.prefetchData()
			}
		}

		Behavior on zoomLevel {
			enabled: root.framed
			NumberAnimation {
				duration: root.easeMs
				easing.type: Easing.InOutCubic
				onFinished: map.prefetchData()
			}
		}

		// Assigned rather than bound: a binding for visibleRegion has to name visibleRegion
		// on its own right-hand side to say "leave it alone when there is nobody", and that
		// is a binding loop. Set from the one signal that means the extent moved.
		Component.onCompleted: root.frame()

		Connections {
			target: People
			function onBoundsChanged() { root.frame() }
		}

		// The map's six keys, answered here rather than in Actions because all of the state
		// they move belongs to this Map. Actions has already decided the context: every id
		// below is announced on the map screen and nowhere else - see docs/input.md.
		Connections {
			target: Actions
			function onInvoked(id) {
				switch (id) {
				case "refresh":
					// clearData() blanks the whole map for a moment - see docs/map.md. The
					// viewport is deliberately left alone: this is about the tiles and the
					// roster, and the list's own `Wszyscy` row is the way back from a framing.
					map.clearData()
					People.refresh()
					break
				case "map-people":
					root.listOpen = !root.listOpen
					break
				case "map-previous":
					root.step(-1)
					break
				case "map-next":
					root.step(1)
					break
				case "map-zoom-in":
					root.zoom(1)
					break
				case "map-zoom-out":
					root.zoom(-1)
					break
				}
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

				// Which rung this label sits on, counting up from the marker. PeopleModel
				// assigns it: a delegate would need every other person to work it out.
				required property int stackIndex

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
						id: box
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

							// Never hidden, and never conditional on `stale`. Two things depend on
							// that: a fix's age is what this line is for, and every box being
							// exactly two lines tall is what makes the stack step below exact.
							Text {
								anchors.horizontalCenter: parent.horizontalCenter
								text: root.detailOf(marker.seenAt, marker.battery)
								color: Theme.textDim
								font.pixelSize: Theme.fontLabel
							}
						}
					}

					// What keeps two people at one address readable: the box is lifted by a
					// whole box per rung, and the dot below it is not. Every marker's dot
					// still lands on its own coordinate - they simply coincide, because the
					// people do.
					//
					// The step is the box's OWN measured height and not arithmetic on
					// Theme.fontLabel, because a Text is taller than its pixelSize by a
					// factor no line here should be guessing at. It is only correct while
					// every box is the same height, which is why the detail line above is
					// drawn unconditionally - hide it for fresh markers and these overlap
					// again, silently.
					Item {
						width: 1
						height: marker.stackIndex * (box.height + Theme.gap)
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

	// One entry of the roster list: who, and the same second line the marker carries.
	component RosterRow: Rectangle {
		id: entry

		property string who: ""
		property string detail: ""
		property bool   selected: false
		property bool   stale: false

		height: body.height + Theme.gap
		radius: 4
		color: entry.selected ? Theme.highlight : "transparent"

		Column {
			id: body
			anchors {
				left: parent.left
				right: parent.right
				top: parent.top
				topMargin: Theme.gap / 2
				leftMargin: Theme.gap
				rightMargin: Theme.gap
			}

			Text {
				width: body.width
				text: entry.who
				color: Theme.text
				font.pixelSize: Theme.fontBody
				elide: Text.ElideRight
			}

			Text {
				width: body.width
				text: entry.detail
				color: entry.stale ? Theme.connecting : Theme.textDim
				font.pixelSize: Theme.fontLabel
				elide: Text.ElideRight
			}
		}
	}

	// The roster list, and the clip it slides behind. The clip is not decoration: the carousel
	// scales this whole screen into a miniature, and a shut list drawn outside the card is drawn
	// across the card beside it.
	Item {
		anchors.fill: map
		clip: true

		Rectangle {
			id: panel

			anchors {
				top: parent.top
				right: parent.right
				bottom: parent.bottom
				margins: Theme.gap
			}
			width: Theme.fontBody * 9

			color: Theme.surface
			border.color: Theme.border
			border.width: 1
			radius: 4

			transform: Translate {
				x: root.listOpen ? 0 : panel.width + Theme.gap * 2
				Behavior on x {
					NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
				}
			}

			// The way back from following anybody, and it is not a row of the model - so it is
			// drawn above the view rather than as its header, where a long roster would scroll
			// it out of reach.
			RosterRow {
				id: everyone
				anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.gap }
				who: "Wszyscy"
				detail: People.count + " na mapie"
				selected: root.followId.length === 0
			}

			ListView {
				id: rosterView

				anchors {
					top: everyone.bottom
					left: parent.left
					right: parent.right
					bottom: parent.bottom
					margins: Theme.gap
					topMargin: Theme.gap / 2
				}

				// Neither is a default worth taking. Focus here starves the one Keys.onPressed
				// in Main.qml, exactly as a MapView would; interactive is a flick gesture on a
				// panel with no pointer to make one, which could only ever leave the list
				// scrolled somewhere nothing here put it.
				focus: false
				interactive: false
				clip: true

				model: People.model
				spacing: Theme.gap / 2

				delegate: RosterRow {
					required property string personId
					required property string name
					required property double seenAt
					required property int battery

					width: ListView.view.width
					who: name
					detail: root.detailOf(seenAt, battery)
					stale: root.now - seenAt > root.staleAfterMs
					selected: root.followId === personId
				}
			}
		}
	}

	// The second line under a name: when the fix was taken, and the phone's charge when the
	// service reported one. A seenAt of 0 asks for no age at all.
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
		return parts.join(" · ")
	}

	function ageOf(ms) {
		var minutes = Math.round(ms / 60000)
		// Rounding alone would draw a fix taken seconds ago as "0 min temu", which reads as a
		// broken clock rather than as a fresh position.
		if (minutes < 1)
			return "teraz"
		if (minutes < 60)
			return minutes + " min temu"

		var hours = Math.round(minutes / 60)
		if (hours < 24)
			return hours + " godz. temu"

		var days = Math.round(hours / 24)
		return days === 1 ? "1 dzień temu" : days + " dni temu"
	}

	// Which row the list is standing on, where -1 is `Wszyscy`. The walk wraps through it, so
	// there is no end of the list to be stuck at and the way back costs no second key.
	function step(delta) {
		var at = root.followId.length > 0 ? People.rowOf(root.followId) : -1
		var next = at + delta
		if (next < -1)
			next = People.count - 1
		if (next >= People.count)
			next = -1
		root.select(next)
	}

	function select(row) {
		root.followId = row < 0 ? "" : People.idAt(row)

		// A walk from one person to the next keeps a held zoom - it is the same framing with
		// another centre. `Wszyscy` drops it, because a fit to the bounds cannot be honoured
		// while a level is held, and the row would then move nothing at all.
		if (root.followId.length === 0)
			root.holdZoom(false)

		if (row < 0)
			rosterView.positionViewAtBeginning()
		else
			rosterView.positionViewAtIndex(row, ListView.Contain)

		root.frame()
	}

	// The clamp is not decoration. Qt clamps zoomLevel itself, but an unclamped TARGET keeps
	// climbing past the end of the range, and ten presses past the maximum are then ten presses
	// of nothing happening on the way back down - which reads as a key that has died. The range
	// is asked of the plugin rather than written down here.
	function zoom(delta) {
		// From the target while a zoom is already in flight, and from the map itself otherwise:
		// frame() writes zoomLevel too, and after it the target is stale. Read before the hold
		// is renewed below, which is what makes three quick presses three levels.
		var from = root.zoomed ? root.zoomTarget : map.zoomLevel

		root.holdZoom(true)
		root.zoomTarget = Math.max(map.minimumZoomLevel,
		                           Math.min(map.maximumZoomLevel, from + delta))
		map.zoomLevel = root.zoomTarget
	}

	// The one writer of the hold, so that `zoomed` and the timer cannot disagree: a set flag
	// with no timer armed is a zoom the map never takes back.
	function holdZoom(on) {
		root.zoomed = on
		if (on)
			zoomHold.restart()
		else
			zoomHold.stop()
	}

	// Where the viewport goes, and the only place that decides it. Called once at startup and
	// then on every poll, so everything it must not undo is tested here.
	function frame() {
		if (root.followId.length > 0) {
			var who = People.person(root.followId)
			if (who.name !== undefined) {
				root.followName = who.name
				map.center = QtPositioning.coordinate(who.latitude, who.longitude)
				if (!root.zoomed)
					map.zoomLevel = root.followZoom
				root.framed = true
				return
			}

			// They stopped sharing. Written straight rather than through select(), which frames
			// - and falling through is the frame. Left alone, the viewport stays parked on a
			// coordinate somebody has left, tracking a marker that is no longer drawn.
			root.followId = ""
			root.holdZoom(false)
		}

		// Nobody is followed below the return above, so the name is cleared here and not in
		// select(): a path that leaves it strands the last person's name in the title, with
		// nothing else on screen wrong.
		root.followName = ""

		if (People.hasBounds && !root.zoomed) {
			map.visibleRegion = root.regionOf()
			root.framed = true
		}
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
