# The <REDACTED> half of the map context

One container. It polls Google for everyone sharing a location, republishes them as the JSON
the panel reads, proxies and caches the map's tiles, and holds the browser the Google session
is renewed in. One published port, and everything is a path under it.

Nothing in this directory is built or shipped by the package — `CMakeLists.txt` does not glob
and `debian/kuchnia.install` names three files, neither of which reaches here. The reasoning,
and everything that fails silently, is in [docs/location.md](../docs/location.md).

## Deploy

```sh
scp -r services/ <user>@<host>:~/kuchnia-location/
cd ~/kuchnia-location
cp .env.example .env      # set VNC_PASSWORD; the container refuses to start without one
docker compose up -d --build
```

Then point one name at `<host>:8087`. Two things the reverse proxy in front has to do:

* allow a **websocket upgrade** under `/vnc/`, with a read timeout in the hours — a default
  around a minute blacks the screen out partway through a sign-in;
* terminate TLS with a certificate the panel's **system trust store already knows**. Its HTTP
  client rejects rather than prompts, and follows no redirects.

Mount it at the root of its own name. The page's own links are relative, so a path prefix
works for a person clicking around, but noVNC builds its websocket URL from the root.

| Path | Password | What |
|---|---|---|
| `/v1/people` | no | the panel's `people-url` |
| `/tiles/{z}/{x}/{y}.png` | no | the panel's `map-tile-url` — **with a trailing slash** |
| `/health` | no | 200 only while the roster is fresh; a dead session takes it down too |
| `/` | yes | status, the sign-in buttons, and every setting |
| `/vnc/` | yes | the sign-in screen |

The three open paths are open because the panel has no credentials to offer.

## The first sign-in, and every one after it

There is no scripted way to do this and there is not going to be: OAuth issues scoped tokens,
there is no location-sharing scope, and the RPC needs `__Secure-1PSID` — a full web-session
cookie that only a real browser produces.

1. Open `/`, press **Start the screen**. An X server, a browser and the websocket bridge come
   up; they are stopped the rest of the time.
2. Press **Open it** and sign in as **the burner account** — not a personal one.
   `__Secure-1PSID` is full account access, and a burner is what keeps that contained.
   Everyone shares their location *to* it, "until you turn this off".
3. Come back and press **Finish & harvest**. The browser is shut down cleanly, its cookies are
   read, and the screen is put away. A profile with no Google session is refused, loudly, and
   the browser comes back so you can carry on.

The roster picks the new jar up by itself, without a restart.

Worth stating plainly: automated access to that endpoint is against Google's terms of service.

## Cleanup

```sh
docker compose down
rm -rf data profile cache          # the jar, the browser profile, the tiles
```

`data/cookies.txt` **is** the Google credential. `data/` and `.env` are both gitignored.

## Checking it without Google

```sh
docker exec kuchnia-location python3 -m app.selftest
```

The roster parser is fixed indices into an undocumented array, and a moved field draws
somebody standing somewhere they are not. That is what this pins, along with the rule that a
dead session is never allowed to answer `{"people": []}`.
