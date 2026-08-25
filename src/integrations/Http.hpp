#pragma once

#include <string>

// The one HTTP client in the program, shared by every service that fetches a URL.
//
// It exists so that the request timeout, the certificate policy and the refusal of a scheme
// that is neither http nor https are each written once. Two clients that must agree on a
// timeout are two places for it to drift, and the one that drifts is the one nobody is
// watching when the LAN goes slow.
namespace http {

// Poco's SSL layer is process-wide and has to be up before the first HTTPS session and down
// after the last one. Called by Integrations around the whole set of services, never per
// request.
void initializeTls();
void shutdownTls();

// GETs url and returns the body, throwing on anything that is not a 200.
//
// `setting` is the config key url came from - "rest-url", "people-url". It is what the
// exceptions name, so a scheme typo or a 404 reports the line to edit rather than the URL
// the line produced. `topic` is the caller's applog topic for the one-line success record.
std::string get(const std::string& url, const char* setting, const char* topic);

}  // namespace http
