-- The tank's archive, in the shape Database.cpp reads: a "CWU_temp" table whose value column
-- is CENTIDEGREES - 4668 is 46.68 C. See docs/database.md.
--
-- Postgres runs this once, when the container initialises an empty data directory. Rows are
-- placed relative to now(), so a `docker compose down` and `up` is what refreshes a seed that
-- has aged out of the 24 h window db-history-hours asks for.

CREATE TABLE "CWU_temp" (
    id          bigserial   PRIMARY KEY,
    "timestamp" timestamptz NOT NULL,
    value       integer     NOT NULL
);

-- 24 hours at one sample a minute, on a six-hour heat-and-cool cycle: a fifteen-percent ramp
-- from 40 to 57 C and an exponential decay back down, plus a little jitter so the line is not
-- a drawn curve. The whole range sits inside the panel's fixed 20-65 C scale.
INSERT INTO "CWU_temp" ("timestamp", value)
SELECT ts, round(100 * celsius)::int
FROM (
    SELECT ts,
           CASE WHEN phase < 0.15
                THEN 40.0 + 17.0 * (phase / 0.15)
                ELSE 57.0 - 17.0 * (1 - exp(-3.2 * (phase - 0.15) / 0.85))
           END
           + 0.25 * sin(extract(epoch FROM ts) / 37.0) AS celsius
    FROM (
        SELECT ts,
               mod(extract(epoch FROM ts)::bigint / 60, 360)::double precision / 360.0 AS phase
        FROM generate_series(now() - interval '24 hours', now(), interval '1 minute') AS ts
    ) cycle
) shaped;
