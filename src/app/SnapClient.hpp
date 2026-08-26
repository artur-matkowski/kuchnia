#pragma once

#include <QString>

#include "Panel.hpp"

class QProcess;
class QTimer;

// The synced radio transport: one snapclient child process joined to a snapserver stream.
//
// This is the second of RadioPanel's two transports and never a fallback beside the first -
// the station's scheme decides which one plays it, and exactly one is ever running. See
// docs/radio.md.
//
// Like CameraFeed, the child is a program and not a library: silence is the absence of a
// process, and there is nothing to link.
class SnapClient : public Panel {
	Q_OBJECT

public:
	explicit SnapClient(QObject* parent = nullptr);
	~SnapClient() override;

	// The one place the snapcast:// scheme is tested. Called from bindings as
	// handles(Radio.url), which re-evaluates because Radio.url notifies.
	Q_INVOKABLE bool handles(const QString& url) const;

	// snapcast://<host>:<port>/<hostID>. Idempotent - RadioPanel reconciles both transports on
	// every station change and on a deferred source drop, and restarting a working child would
	// cut the audio each time.
	//
	// All three parts are required: a missing port or
	// hostID fails with the line quoted rather than defaulting to 1704 and to the MAC
	// address, which would play and be named wrong in snapweb with nothing to say so.
	Q_INVOKABLE void play(const QString& url);
	Q_INVOKABLE void stop();

private:
	void onStderr();
	void note(const QString& line);

	// setHealth, and the log line that goes with it. The card is the only other place this
	// shows, and a board is diagnosed from its journal.
	void report(Health health, const QString& detail);

	QProcess* m_child   = nullptr;
	QTimer*   m_connect = nullptr;

	// What the running child was started for, so play() can tell a reconcile that changes
	// nothing from one that changes the station.
	QString m_url;

	// The last thing the child said, which is what a bare exit has to be explained with.
	QString m_lastLine;
};
