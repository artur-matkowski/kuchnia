"""The shared-location service the demo map reads, with nobody's real position in it.

Answers the one route people-url asks for, in the shape docs/map.md documents. Positions are
fixed: the demo is static, and what moves in a recording moves because the scene animates it.

seen_at is computed per request rather than baked in, so a marker's age stays plausible however
long the panel has been up - the age is drawn on every marker and MapPanel resamples it once a
minute.
"""

import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8087

# Warsaw. Three of these exercise something the map does and are not arbitrary:
#
#  * Kasia and Michal are 30 m apart, inside PeopleModel's kSamePlaceDegrees of 0.001, so their
#    labels stack instead of drawing on top of each other;
#  * Ewa's fix is 40 minutes old, past MapPanel.staleAfterMs, so her marker is amber;
#  * Filip reports no battery, which reaches the scene as -1 and draws no battery at all.
#
# age is seconds before now.
PEOPLE = [
    {"id": "ala",    "name": "Ala",    "lat": 52.2319,  "lon": 21.0067,  "acc": 18,  "age": 90,   "bat": 78},
    {"id": "bartek", "name": "Bartek", "lat": 52.2297,  "lon": 20.9840,  "acc": 42,  "age": 240,  "bat": 34},
    {"id": "kasia",  "name": "Kasia",  "lat": 52.2690,  "lon": 20.9860,  "acc": 25,  "age": 180,  "bat": 91},
    {"id": "michal", "name": "Michał", "lat": 52.26918, "lon": 20.98632, "acc": 67,  "age": 420,  "bat": 12},
    {"id": "ewa",    "name": "Ewa",    "lat": 52.2100,  "lon": 21.0180,  "acc": 110, "age": 2400, "bat": 56},
    {"id": "filip",  "name": "Filip",  "lat": 52.2440,  "lon": 21.0800,  "acc": 33,  "age": 300,  "bat": None},
]


def roster():
    now = int(time.time())
    people = []
    for person in PEOPLE:
        row = {
            "id": person["id"],
            "name": person["name"],
            "lat": person["lat"],
            "lon": person["lon"],
            "accuracy_m": person["acc"],
            "seen_at": now - person["age"],
        }
        # Absent rather than null: a phone that did not report and a phone at 0% are different
        # facts, and the parser turns an absent key into -1.
        if person["bat"] is not None:
            row["battery"] = person["bat"]
        people.append(row)
    return {"people": people}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/v1/people":
            self.send_error(404)
            return
        body = json.dumps(roster()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("%s %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    print(f"roster on :{PORT}, {len(PEOPLE)} people", flush=True)
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
