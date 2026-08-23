# The broker client

> Owns: src/integrations/Mqtt.hpp
> Owns: src/integrations/Mqtt.cpp
> See:  docs/integrations.md

A `Service` like the other two — read [integrations](docs/integrations.md) first for the
thread, the backoff and the settings. What is particular to this one is below.

**Nothing may `wait()` on a token inside a paho callback.** That thread is the one that
delivers `SUBACK` and `PUBACK`, so the token it waits for can never complete: the client
stops dead with no error, no traffic and no log line, looking exactly like a broker that
went quiet. `onConnected()` therefore only flags the work and calls `wake()`; `step()` runs
it on the service thread, where a failure still propagates to `Service` and is retried.

**A gate command from the scene is queued, never published where it was raised.**
`requestGateCommand()` takes a lock, appends, and calls `wake()`; `step()` drains the queue
outside the lock. `publish()` waits for the broker's PUBACK, and the caller is the thread
painting the screen — publishing there freezes the scene for as long as the LAN takes, and
holding the lock across it stalls the next button press as well.

`gate-command` in the config is a separate, one-shot path for bringing the bridge up by hand.
The scene's buttons are not limited to one.

**Reconnection is paho's, not `Service`'s.** The client is configured with
`automatic_reconnect`, and the connected handler — which runs on the first connect and every
reconnect after — is what re-establishes the subscriptions and the retained status. `Service`'s backoff only covers a connect that never succeeded at all.

That has a consequence for the status the scene shows: a broker that goes away after a
successful connect never makes `step()` throw, so `Service` never reports it. The connection
lost handler is the only place it can be seen.

**A refused connect names the identity it was refused for.** paho renders every CONNACK
rejection as `CONNACK return code`, which says neither the meaning of the code nor what was
sent; `connackReason()` translates it and the message adds the user, the client id, whether
a password was set and the will topic. Code 5, *not authorized*, covers a wrong password, an
unknown account **and** a will topic the broker's ACL denies — the last refuses a connect
whose credentials are perfect.

**`mqtt-user` is the account, `mqtt-client-id` is the session.** They are unrelated: putting
the broker account in the client id authenticates as whatever `mqtt-user` defaults to.

The client id must also be unique on the broker: two clients sharing one disconnect each
other in a loop that reads as a flapping network.

**Nothing under `hc12/tx` may ever be published retained.** The broker persists retained
messages, so a retained `hc12/tx/OpenGate` is replayed to the HC-12 bridge on every restart
of *that* service — the gate then opens by itself, forever, until someone clears the topic
by hand. `publish()` takes the flag explicitly and `sendGateCommand()` passes false.

MQTT has no prefix wildcard, so the gate topics are named one by one in `kGateTopics` — a
signal added to `hc12-message-definitions` needs adding there too.
