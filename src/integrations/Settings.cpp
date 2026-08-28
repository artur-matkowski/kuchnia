#include "Settings.hpp"

#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <stdexcept>

#include <sys/stat.h>

#include "Config.hpp"
#include "Log.hpp"

std::string defaultConfigPath()
{
	if (const char* xdg = std::getenv("XDG_CONFIG_HOME"); xdg && *xdg)
		return std::string(xdg) + "/kuchnia/config.conf";
	if (const char* home = std::getenv("HOME"); home && *home)
		return std::string(home) + "/.config/kuchnia/config.conf";
	return {};
}

namespace {

// Module-cpp-config takes --configpath out of this same argv and never says which file it
// settled on. Reading it here too is what keeps a run that names its own config from needing
// a home directory, a config directory or a chmod.
bool configPathGiven(int argc, char** argv)
{
	for (int i = 1; i < argc; ++i)
		if (std::string(argv[i]) == "--configpath" && i + 1 < argc)
			return true;
	return false;
}

// The two directories above the config file. The module writes it with a bare ofstream, which
// creates no parent, so a first start on an account that has never had one writes nothing.
bool makeConfigDirectory(const std::string& path)
{
	const std::string dir  = path.substr(0, path.rfind('/'));
	const std::string base = dir.substr(0, dir.rfind('/'));
	for (const std::string& each : {base, dir})
		if (::mkdir(each.c_str(), 0700) != 0 && errno != EEXIST)
			return false;
	return true;
}

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
			"Lowest level that reaches stdout: debug, info, warning or error. A topic can be "
			"raised on its own after it - info,QT=debug,PERF=debug"),

		// BOOL and not FLAG: a FLAG's default is hardwired false and no config line can turn
		// it on, and this one has to default to on for the board. The parser is
		// `value == "true"` exactly, so `fullscreen:True` reads as false without a word.
		ParamInitializer(BOOL, "fullscreen", true,
			"Take the whole screen; false is a window the size the scene is composed at"),

		ParamInitializer(STRING, "db-host", "<HOST_REDACTED>", "PostgreSQL host"),
		ParamInitializer(INT,    "db-port", 0,              "PostgreSQL port"),
		ParamInitializer(STRING, "db-name", "house_db",        "PostgreSQL database"),
		ParamInitializer(STRING, "db-user", "admin",           "PostgreSQL role"),
		ParamInitializer(STRING, "db-password", "",            "PostgreSQL password"),
		ParamInitializer(INT,    "db-interval-ms", 30000,      "Milliseconds between polls"),
		ParamInitializer(INT,    "db-history-hours", 24,
			"Width of the hot water history window"),

		// The scene draws current.*, both hourly.* arrays and the daily sunrise/sunset pair.
		// Dropping a field from this query does not fail the request - open-meteo simply omits
		// it, and the panel that wanted it stays empty. A timezone parameter must never be
		// added here: every timestamp is parsed as UTC - see docs/rest.md.
		ParamInitializer(STRING, "rest-url",
			"https://api.open-meteo.com/v1/forecast"
			"?latitude=<COORD_REDACTED>&longitude=<COORD_REDACTED>"
			"&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,"
			"wind_direction_10m,cloud_cover,rain,snowfall"
			"&hourly=temperature_2m,precipitation_probability,precipitation,cloud_cover"
			"&daily=sunrise,sunset&forecast_days=8",
			"Absolute URL fetched on every poll; http and https both work"),
		ParamInitializer(INT,    "rest-interval-ms", 300000,   "Milliseconds between fetches"),

		// The location service, not Google: the scrape that produces this lives in the <REDACTED>
		// so that its cookie jar does not - see docs/map.md. Every field this parses is
		// required, so a service answering a different shape fails loudly rather than drawing
		// an empty map.
		ParamInitializer(STRING, "people-url", "http://127.0.0.1:8087/v1/people",
			"Absolute URL of the shared-location service; http and https both work"),
		ParamInitializer(INT,    "people-interval-ms", 60000, "Milliseconds between fetches"),

		// The same host as people-url, on a different path: one container serves the roster
		// and proxies the tiles, so the board has one name to resolve and one certificate to
		// trust - see docs/location.md. The map also turns off Qt's own provider lookup, so
		// this is the only tile source there is.
		// THE TRAILING SLASH IS LOAD-BEARING. The osm plugin appends "%z/%x/%y.png" to this
		// string with no separator of its own, so a host written without one asks for
		// "https://host8/83/138.png" - a host name with the zoom level welded onto it, which
		// resolves nowhere and reports itself as a DNS failure rather than as a bad setting.
		ParamInitializer(STRING, "map-tile-url", "http://127.0.0.1:8087/tiles/",
			"Tile server for the map context, WITH a trailing slash; '%z/%x/%y.png' is "
			"appended to it unless it already ends in .png"),

		ParamInitializer(STRING, "mqtt-host", "<HOST_REDACTED>", "Broker address"),
		ParamInitializer(INT,    "mqtt-port", 0,               "Broker port"),
		ParamInitializer(STRING, "mqtt-user", "kuchnia",
			"Broker account the password authenticates, and not the client id"),
		ParamInitializer(STRING, "mqtt-password", "",             "Broker password"),
		ParamInitializer(STRING, "mqtt-client-id", "kuchnia",
			"Session name, not an account; unique on the broker or both clients flap"),
		ParamInitializer(STRING_VECTOR, "mqtt-subscribe", kGateTopics,
			"Topics subscribed on every connect"),
		ParamInitializer(STRING, "mqtt-status-topic", "kuchnia/available",
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
			"RTSP stream per camera tile, comma separated; the tile filling the screen is the "
			"only one ever heard"),
		// tcp and not auto, which is what ffmpeg does unasked: auto tries UDP first, and a peer
		// that refuses it answers 461 and costs a round trip. Every stream here opens as fast
		// on TCP, and the go2rtc proxy opens on nothing else.
		ParamInitializer(STRING, "camera-transport", "tcp",
			"RTSP transport asked for: tcp, udp, or auto to let ffmpeg choose"),
		ParamInitializer(INT, "camera-hold-ms", 60000,
			"How long a camera keeps its stream after its context leaves the screen; "
			"negative never disconnects"),

		ParamInitializer(STRING_VECTOR, "radio-m3u", std::vector<std::string>{"/etc/radio.m3u"},
			"Extended M3U playlists the radio stations are read from, comma separated; read in "
			"order and concatenated into one list"),

		ParamInitializer(STRING, "key-bindings", "",
			"INI file the key bindings are read from and written to; "
			"empty is the standard per-user config location"),
		ParamInitializer(FLAG,   "key-reset",
			"Erase the key bindings on this start and write the defaults back"),

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

	// ArgInit reads --configpath out of argv itself and overrides this path with it; that run
	// owns its own file, so none of the directory or permission work below applies to it.
	const bool ownPath = !configPathGiven(argc, argv);
	const std::string path = defaultConfigPath();

	if (ownPath) {
		if (path.empty()) {
			*message = "neither XDG_CONFIG_HOME nor HOME is set, so there is nowhere to keep "
			           "the config; name a file with --configpath";
			return SettingsResult::Failed;
		}
		if (!makeConfigDirectory(path)) {
			*message = "cannot create the directory for " + path + ": " + std::strerror(errno);
			return SettingsResult::Failed;
		}
	}

	struct stat unused;
	const bool existed = ownPath && ::stat(path.c_str(), &unused) == 0;

	bool parsed = false;
	try {
		// stoi and stof throw on a value that is not a number, from the file, the
		// environment and argv alike. Uncaught that is a terminate() during startup with
		// no indication of which parameter was malformed.
		parsed = Config::Instance().ArgInit(path, specs(), argc, argv, message);
	} catch (const std::exception& error) {
		*message = std::string("malformed value in config, environment or arguments: ") + error.what();
		return SettingsResult::Failed;
	}

	// The module writes the defaults for a path it could not read, with a bare ofstream and so
	// at whatever the umask allows. Both passwords go in this file.
	if (!existed && ownPath && ::stat(path.c_str(), &unused) == 0) {
		if (::chmod(path.c_str(), 0600) != 0)
			LOG_ERROR(applog::Cfg) << "cannot restrict " << path << ": " << std::strerror(errno);
		else
			LOG_INFO(applog::Cfg) << "wrote a default config: " << path;
	}

	if (Config::Instance().IsHelpPrintoutRequested()) {
		*message = Config::Instance().PrintHelp();
		return SettingsResult::HelpRequested;
	}
	if (!parsed)
		return SettingsResult::Failed;

	get("log-level", &out->logLevel);
	get("fullscreen", &out->fullscreen);

	get("db-host", &out->dbHost);
	get("db-port", &out->dbPort);
	get("db-name", &out->dbName);
	get("db-user", &out->dbUser);
	get("db-password", &out->dbPassword);
	get("db-interval-ms", &out->dbIntervalMs);
	get("db-history-hours", &out->dbHistoryHours);

	get("rest-url", &out->restUrl);
	get("rest-interval-ms", &out->restIntervalMs);

	get("people-url", &out->peopleUrl);
	get("people-interval-ms", &out->peopleIntervalMs);
	get("map-tile-url", &out->mapTileUrl);

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
	get("camera-transport", &out->cameraTransport);
	get("camera-hold-ms", &out->cameraHoldMs);
	get("radio-m3u", &out->radioM3u);
	get("key-bindings", &out->keyBindings);
	get("key-reset", &out->keyReset);

	get("retry-min-ms", &out->retryMinMs);
	get("retry-max-ms", &out->retryMaxMs);

	return SettingsResult::Ok;
}
