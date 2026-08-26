#pragma once

#include <QObject>
#include <QString>

// The two volume keys, and nothing else. There is no level here to bind to and no slider on
// any screen: the sink belongs to the sound server and is shared with whatever else the board
// is playing, so what it stands at is the server's to know - see docs/volume.md.
class Volume : public QObject {
	Q_OBJECT

public:
	using QObject::QObject;

	// One step each, applied to the default sink. They report nothing back: a press that could
	// not be carried out is an error in the log, because the panel draws no volume to be wrong.
	Q_INVOKABLE void up();
	Q_INVOKABLE void down();

private:
	void step(const QString& delta);
};
