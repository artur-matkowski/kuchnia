#include "Location.hpp"

#include <stdexcept>
#include <string>
#include <utility>

#include <Poco/JSON/Array.h>
#include <Poco/JSON/Object.h>
#include <Poco/JSON/Parser.h>

#include "Http.hpp"
#include "Log.hpp"

namespace {

// Every required field goes through here. Poco's getValue<double> on an absent key throws
// something that names the key and nothing else; the caller wants to know which person, and
// which config line points at the service that produced them.
double required(const Poco::JSON::Object::Ptr& person, const char* key, std::size_t index)
{
	if (!person->has(key) || person->isNull(key))
		throw std::runtime_error("people[" + std::to_string(index) + "] has no '" + key +
		                         "' - check people-url");
	return person->getValue<double>(key);
}

std::string requiredText(const Poco::JSON::Object::Ptr& person, const char* key, std::size_t index)
{
	if (!person->has(key) || person->isNull(key))
		throw std::runtime_error("people[" + std::to_string(index) + "] has no '" + key +
		                         "' - check people-url");
	return person->getValue<std::string>(key);
}

PeopleUpdate parseRoster(const char* topic, const std::string& body)
{
	// Poco's own parse failure says "JSON Exception" and nothing else - not the URL, not a
	// line number. On a board that message is indistinguishable from any other JSON in the
	// program failing, so it is caught here and given the one fact that makes it actionable.
	Poco::JSON::Object::Ptr root;
	try {
		Poco::JSON::Parser parser;
		root = parser.parse(body).extract<Poco::JSON::Object::Ptr>();
	} catch (const std::exception& error) {
		throw std::runtime_error(std::string("the response is not a JSON object (") +
		                         error.what() + ") - check people-url");
	}

	// An absent array and an empty one are different answers and only one of them is news.
	// Empty means nobody is sharing right now and the map draws no markers; absent means the
	// response is not the shape this parses, and saying so beats an empty map that looks
	// exactly like everyone having gone offline at once.
	const Poco::JSON::Array::Ptr list = root->getArray("people");
	if (!list)
		throw std::runtime_error("no 'people' array in the response - check people-url");

	PeopleUpdate update;
	update.people.reserve(list->size());

	for (std::size_t i = 0; i < list->size(); ++i) {
		const Poco::JSON::Object::Ptr entry = list->getObject(i);
		if (!entry)
			throw std::runtime_error("people[" + std::to_string(i) +
			                         "] is not an object - check people-url");

		Person person;
		person.id        = requiredText(entry, "id", i);
		person.latitude  = required(entry, "lat", i);
		person.longitude = required(entry, "lon", i);
		person.seenAt    = required(entry, "seen_at", i);

		// The optional pair. A person with no name is drawn by their id rather than by a
		// blank marker, and a battery nobody reported stays out of range - see Sinks.hpp.
		person.name = entry->has("name") && !entry->isNull("name")
			? entry->getValue<std::string>("name") : person.id;
		if (entry->has("accuracy_m") && !entry->isNull("accuracy_m"))
			person.accuracy = entry->getValue<double>("accuracy_m");
		if (entry->has("battery") && !entry->isNull("battery"))
			person.battery = entry->getValue<int>("battery");

		update.people.push_back(std::move(person));
	}

	LOG_INFO(topic) << update.people.size() << " person(s) sharing";
	return update;
}

}  // namespace

Location::Location(const Settings& settings, Sinks sinks)
	: Service(applog::Location, settings.retryMinMs, settings.retryMaxMs)
	, m_settings(settings)
	, m_sinks(std::move(sinks))
{
}

Location::~Location()
{
	stop();
}

void Location::step()
{
	const std::string body = http::get(m_settings.peopleUrl, "people-url", topic());

	const PeopleUpdate update = parseRoster(topic(), body);
	reportHealth(Health::Live);
	if (m_sinks.people)
		m_sinks.people(update);

	waitFor(m_settings.peopleIntervalMs);
}
