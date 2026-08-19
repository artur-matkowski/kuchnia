pragma Singleton
import QtQuick

// Where a panel goes.
//
// No screen in this scene is arranged by QtQuick.Layouts, and that is deliberate. A layout
// owns its children's geometry: it reassigns x, y, width and height whenever anything about
// it changes - a sibling going invisible is enough - and an element whose box is being
// animated loses that argument without a word. Here a box is a value computed from the
// screen's own size, and an element that has to be somewhere else animates it.
QtObject {
	// One cell of a grid that is not a layout. `columns` and `rows` are one entry per band: a
	// number is that band's size, and -1 takes an equal share of whatever the fixed ones leave.
	// Gaps fall between bands and never around them, so a cell exactly fills its bounds - which
	// is what lets a cell be handed back in as the bounds of a finer grid.
	function box(bounds, columns, rows, column, row, columnSpan, rowSpan) {
		var across = _band(bounds.x, bounds.width, columns, column, columnSpan || 1)
		var down = _band(bounds.y, bounds.height, rows, row, rowSpan || 1)
		return Qt.rect(across.at, down.at, across.size, down.size)
	}

	function _band(origin, total, sizes, index, span) {
		var fixed = 0
		var flexible = 0
		for (var i = 0; i < sizes.length; ++i) {
			if (sizes[i] < 0)
				++flexible
			else
				fixed += sizes[i]
		}

		var share = flexible > 0
			? (total - Theme.gap * (sizes.length - 1) - fixed) / flexible
			: 0

		var at = origin
		for (var before = 0; before < index; ++before)
			at += (sizes[before] < 0 ? share : sizes[before]) + Theme.gap

		var size = Theme.gap * (span - 1)
		for (var band = index; band < index + span; ++band)
			size += sizes[band] < 0 ? share : sizes[band]

		return { at: at, size: size }
	}
}
