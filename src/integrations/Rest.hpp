#pragma once

#include "Service.hpp"
#include "Settings.hpp"

// Fetches one configured URL on an interval through Poco, and reports what came back.
//
// rest-url points at the <REDACTED>'s open-meteo cache by default, so the response is parsed as
// open-meteo's forecast shape when it has one. Any other JSON is still fetched and reported;
// only the temperature line goes missing.
class Rest : public Service {
public:
	explicit Rest(const Settings& settings);
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
};
