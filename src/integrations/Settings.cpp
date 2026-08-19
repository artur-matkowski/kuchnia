#include "Settings.hpp"

#include <stdexcept>

#include "Config.hpp"
#include "Log.hpp"

const char* const kDefaultConfigPath = "/etc/qt-hmi.conf";

namespace {

// The gate signals the HC-12 bridge republishes. MQTT has no prefix wildcard, so there is no
// way to say "every hc12/rx topic whose name starts with Gate" - each one is named, and a
// signal added to hc12-message-definitions needs adding here too.
const std::vector<std::string> kGateTopics = {
	"hc12/rx/GateOpened",
	"hc12/rx/GateClosed",
	"hc12/rx/GateOpening",
	"hc12/rx/GateClosing",
	"hc12/rx/GateStopped",
	"hc12/rx/GateStuckOpening",
	"hc12/rx/GateStuckClosing",
};

std::vector<ParamInitializer> specs()
{
	return {
		ParamInitializer(STRING, "log-level", "info",
			"Lowest level that reaches stdout: debug, info, warning or error"),

		ParamInitializer(STRING, "db-host", "<HOST_REDACTED>", "PostgreSQL host"),
		ParamInitializer(INT,    "db-port", 0,              "PostgreSQL port"),
		ParamInitializer(STRING, "db-name", "house_db",    "PostgreSQL database"),
		ParamInitializer(STRING, "db-user", "admin",           "PostgreSQL role"),
		ParamInitializer(STRING, "db-password", "",            "PostgreSQL password"),
		ParamInitializer(INT,    "db-interval-ms", 30000,      "Milliseconds between polls"),
		ParamInitializer(INT,    "db-history-hours", 24,
			"Width of the hot water history window"),

		// The scene draws current.* and both hourly.* arrays. Dropping a field from this query
		// does not fail the request - open-meteo simply omits it, and the panel that wanted it
		// stays empty.
		ParamInitializer(STRING, "rest-url",
			"https://api.open-meteo.com/v1/forecast"
			"?latitude=<COORD_REDACTED>&longitude=<COORD_REDACTED>"
			"&current=temperature_2m,relative_humidity_2m,weather_code"
			"&hourly=temperature_2m,precipitation_probability&forecast_days=2",
			"Absolute URL fetched on every poll; http and https both work"),
		ParamInitializer(INT,    "rest-interval-ms", 300000,   "Milliseconds between fetches"),

		ParamInitializer(STRING, "mqtt-host", "<HOST_REDACTED>", "Broker address"),
		ParamInitializer(INT,    "mqtt-port", 0,             "Broker port"),
		ParamInitializer(STRING, "mqtt-user", "qt-hmi",
			"Broker account the password authenticates, and not the client id"),
		ParamInitializer(STRING, "mqtt-password", "",           "Broker password"),
		ParamInitializer(STRING, "mqtt-client-id", "qt-hmi",
			"Session name, not an account; unique on the broker or both clients flap"),
		ParamInitializer(STRING_VECTOR, "mqtt-subscribe", kGateTopics,
			"Topics subscribed on every connect"),
		ParamInitializer(STRING, "mqtt-status-topic", "qt-hmi/available",
			"Retained online/offline topic, also this client's last will"),
		ParamInitializer(INT,    "mqtt-heartbeat-ms", 60000,
			"Milliseconds between heartbeat publishes; 0 disables them"),

		ParamInitializer(FLAG,   "gate-control",
			"Allow publishing to hc12/tx - without it gate-command is refused"),
		ParamInitializer(STRING, "gate-command", "",
			"One of OpenGate, CloseGate or StopGate, published once after the first connect"),
		ParamInitializer(INT,    "gate-target", 4,
			"HC-12 node id the gate command addresses"),

		ParamInitializer(STRING_VECTOR, "camera-url", std::vector<std::string>(),
			"RTSP stream per camera tile, comma separated; audio from these is always muted"),

		ParamInitializer(STRING_VECTOR, "radio-url", std::vector<std::string>(),
			"Station stream URLs, comma separated"),
		ParamInitializer(STRING_VECTOR, "radio-name", std::vector<std::string>(),
			"Station labels, comma separated and in the same order as radio-url"),

		ParamInitializer(INT, "retry-min-ms", 1000,  "First delay after a failed attempt"),
		ParamInitializer(INT, "retry-max-ms", 30000, "Ceiling the backoff doubles up to"),
	};
}

// Config::Get returns false for a name that is not in the table, and leaves the output
// untouched. Every miss here is a typo between specs() and this function, so it is worth
// saying out loud rather than silently keeping a default.
template <typename T>
void get(const char* key, T* out)
{
	if (!Config::Instance().Get(key, out))
		LOG_ERROR(applog::Cfg) << "no such parameter: " << key;
}

}  // namespace

SettingsResult loadSettings(int argc, char** argv, Settings* out, std::string* message)
{
	// Module-cpp-config logs into four std::ostreams that default to cerr and cout. Pointing
	// them at the logger is what puts a missing config file, or a default one being written,
	// in the same stream and the same format as everything else the program says.
	Config::SetStaticLogStreams(applog::stream(debug::LogLevel::Error, applog::Cfg),
	                            applog::stream(debug::LogLevel::Warning, applog::Cfg),
	                            applog::stream(debug::LogLevel::Info, applog::Cfg),
	                            applog::stream(debug::LogLevel::Debug, applog::Cfg));

	bool parsed = false;
	try {
		// stoi and stof throw on a value that is not a number, from the file, the
		// environment and argv alike. Uncaught that is a terminate() during startup with
		// no indication of which parameter was malformed.
		parsed = Config::Instance().ArgInit(kDefaultConfigPath, specs(), argc, argv, message);
	} catch (const std::exception& error) {
		*message = std::string("malformed value in config, environment or arguments: ") + error.what();
		return SettingsResult::Failed;
	}

	if (Config::Instance().IsHelpPrintoutRequested()) {
		*message = Config::Instance().PrintHelp();
		return SettingsResult::HelpRequested;
	}
	if (!parsed)
		return SettingsResult::Failed;

	get("log-level", &out->logLevel);

	get("db-host", &out->dbHost);
	get("db-port", &out->dbPort);
	get("db-name", &out->dbName);
	get("db-user", &out->dbUser);
	get("db-password", &out->dbPassword);
	get("db-interval-ms", &out->dbIntervalMs);
	get("db-history-hours", &out->dbHistoryHours);

	get("rest-url", &out->restUrl);
	get("rest-interval-ms", &out->restIntervalMs);

	get("mqtt-host", &out->mqttHost);
	get("mqtt-port", &out->mqttPort);
	get("mqtt-user", &out->mqttUser);
	get("mqtt-password", &out->mqttPassword);
	get("mqtt-client-id", &out->mqttClientId);
	get("mqtt-subscribe", &out->mqttSubscribe);
	get("mqtt-status-topic", &out->mqttStatusTopic);
	get("mqtt-heartbeat-ms", &out->mqttHeartbeatMs);

	get("gate-control", &out->gateControl);
	get("gate-command", &out->gateCommand);
	get("gate-target", &out->gateTarget);

	get("camera-url", &out->cameraUrls);
	get("radio-url", &out->radioUrls);
	get("radio-name", &out->radioNames);

	get("retry-min-ms", &out->retryMinMs);
	get("retry-max-ms", &out->retryMaxMs);

	// A short radio-name is not a cosmetic problem: the scene indexes both arrays with one
	// station number, and a name that is simply absent reads on screen as a station that
	// exists and is nameless.
	if (!out->radioNames.empty() && out->radioNames.size() != out->radioUrls.size()) {
		*message = "radio-name has " + std::to_string(out->radioNames.size()) +
		           " entries and radio-url has " + std::to_string(out->radioUrls.size()) +
		           "; they are one list read with one index. Note that both split on commas, "
		           "so a station name containing one becomes two names.";
		return SettingsResult::Failed;
	}

	return SettingsResult::Ok;
}
