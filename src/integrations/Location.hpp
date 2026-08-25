#pragma once

#include "Service.hpp"
#include "Settings.hpp"
#include "Sinks.hpp"

// Fetches people-url on an interval and parses the location service's roster.
//
// Named for what it talks to rather than for what it carries, the way Rest and Database are:
// the facade the scene reads is src/app/People.hpp, and two classes called People in one
// global namespace is a forward declaration in Integrations.hpp binding to the wrong one -
// which compiles.
//
// Unlike Rest, nothing here is optional. The service on the other end is ours - see the
// contract in docs/map.md - so a person without a coordinate or a timestamp is a bug in it,
// not a field this query did not ask for, and it is thrown rather than defaulted. A missing
// coordinate defaulted to zero would put somebody in the Atlantic off Ghana, which is a
// place the map will happily draw.
class Location : public Service {
public:
	Location(const Settings& settings, Sinks sinks);
	~Location() override;

	// Polls now instead of at the end of the current people-interval-ms. Safe from any
	// thread - it is the GUI thread that calls it, through People's refresh sink.
	void refresh() { wake(); }

protected:
	void step() override;

private:
	const Settings& m_settings;
	Sinks           m_sinks;
};
