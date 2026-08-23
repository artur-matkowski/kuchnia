#pragma once

#include <string>
#include <vector>

// The whole parameter set, resolved once at startup and read-only afterwards.
//
// Config.hpp is deliberately not included here. It puts INT, FLOAT, STRING, BOOL and FLAG
// into the global namespace as bare enumerators, and every header that pulls them in is one
// identifier away from a collision reported somewhere else entirely. Settings.cpp is the
// only translation unit that sees them.
struct Settings {
	std::string logLevel;

	// Whether the window asks the session for the whole screen. False is a windowed
	// composition-sized preview; nothing here reads it - see src/qml/Main.qml.
	bool fullscreen = true;

	std::string dbHost;
	int         dbPort = 0;
	std::string dbName;
	std::string dbUser;
	std::string dbPassword;
	int         dbIntervalMs = 0;
	int         dbHistoryHours = 0;

	std::string restUrl;
	int         restIntervalMs = 0;

	std::string              mqttHost;
	int                      mqttPort = 0;
	std::string              mqttUser;
	std::string              mqttPassword;
	std::string              mqttClientId;
	std::vector<std::string> mqttSubscribe;
	std::string              mqttStatusTopic;
	int                      mqttHeartbeatMs = 0;

	bool        gateControl = false;
	std::string gateCommand;
	int         gateTarget = 0;

	std::vector<std::string> cameraUrls;
	int                      cameraHoldMs = 0;

	// The playlist the stations are read from. Nothing here parses it - see src/app/Radio.cpp.
	std::string radioM3u;

	// The key binding file, and whether to throw it away on this start. Empty means the
	// standard per-user config location; nothing here reads either - see src/app/KeyBindings.cpp.
	std::string keyBindings;
	bool        keyReset = false;

	int retryMinMs = 0;
	int retryMaxMs = 0;
};

// The config file the board reads. Overridden by --configpath, which is Module-cpp-config's
// own argument and never appears in the table below.
extern const char* const kDefaultConfigPath;

enum class SettingsResult {
	Ok,
	HelpRequested,  // --help was passed; `message` is the help text, and the caller exits 0
	Failed,         // `message` says what did not parse, and the caller exits non-zero
};

// Resolves the config file, then the environment, then argv - lowest to highest priority.
// Writes a default config file when the path cannot be read, which is how a board with no
// /etc/kuchnia.conf ends up with a documented one after its first boot.
SettingsResult loadSettings(int argc, char** argv, Settings* out, std::string* message);
