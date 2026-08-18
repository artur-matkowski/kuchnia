#pragma once

#include <condition_variable>
#include <mutex>
#include <thread>

// One background worker with an exponential backoff.
//
// Each integration talks to something on the network that may be down at boot and may go
// away at any point after it, and none of them may take the process with them - the screen
// is the point of the program and it has to keep painting whatever the LAN is doing. So a
// service loops, and anything thrown inside a step is caught, logged against the service's
// topic, and retried with the delay doubled up to a ceiling.
//
// The loop runs on its own thread and never touches Qt. Nothing here is a QObject and
// nothing signals the GUI thread, because no part of the scene reads any of it yet.
class Service {
public:
	Service(const char* topic, int retryMinMs, int retryMaxMs);
	virtual ~Service();

	Service(const Service&) = delete;
	Service& operator=(const Service&) = delete;

	void start();
	// Idempotent, and safe to call from the destructor of a derived class - which is where
	// it has to be called, since the thread runs a virtual and the base destructor is too
	// late to stop it.
	void stop();

protected:
	// Runs on the worker thread. Throwing is how a step reports failure; returning normally
	// resets the backoff to its minimum. A step that sleeps does so through waitFor(), so a
	// stop() is never held up by one.
	virtual void step() = 0;

	// Called after a step threw, before the backoff sleep. The default does nothing;
	// override it to drop a connection that must not be reused.
	virtual void reset() {}

	// Sleeps unless a stop is pending. False means the service is shutting down and the
	// caller must return promptly.
	bool waitFor(int milliseconds);

	// Cuts the current waitFor() short. Safe from any thread, which is the whole point: it
	// is how a library's callback thread hands work back to this one instead of doing it
	// where it cannot block. A wake with nobody waiting is remembered, not lost.
	void wake();

	bool stopping();

	const char* topic() const { return m_topic; }

private:
	void run();

	const char*             m_topic;
	int                     m_retryMinMs;
	int                     m_retryMaxMs;
	std::thread             m_thread;
	std::mutex              m_mutex;
	std::condition_variable m_wakeup;
	bool                    m_stopping = false;
	bool                    m_woken = false;
};
