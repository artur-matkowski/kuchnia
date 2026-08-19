#pragma once

#include "Service.hpp"
#include "Settings.hpp"
#include "Sinks.hpp"

// Fetches rest-url on an interval through Poco and parses it as open-meteo's forecast shape.
//
// Every field is optional on the way in: open-meteo answers 200 with the fields it was asked
// for and silently omits the rest, so a typo in the query string produces a valid response
// with a missing key rather than an error. A key that is absent leaves its part of the
// update at zero and its series empty, and the panel says so.
class Rest : public Service {
public:
	Rest(const Settings& settings, Sinks sinks);
	~Rest() override;

	// Poco's SSL layer is process-wide and has to be up before the first HTTPS session and
	// down after the last one. Called by Integrations around the whole set of services, not
	// per request.
	static void initializeTls();
	static void shutdownTls();

protected:
	void step() override;

private:
	const Settings& m_settings;
	Sinks           m_sinks;
};
