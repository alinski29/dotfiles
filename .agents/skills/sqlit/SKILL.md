---
name: sqlit
description: Query and inspect SQL databases through the sqlit CLI (`sqlit query`). Use when inspecting schema, listing tables, or running SELECT/SQL in a sandbox.
---

# sqlit

Run SQL through `sqlit query`. Every session uses a throwaway config dir, and the secret travels on stdin. The OS keyring and D-Bus are never touched.

## 1. Resolve the connection

Find credentials in this order and stop at the first complete set:

1. Explicit instruction in this conversation.
2. An `AGENTS.md` (project root or any ancestor) naming a database.
3. A `.env.example` (search the repo, e.g. `**/.env.example`); treat its values as the dev defaults: `DATABASE_URL`, `POSTGRES_*`, `MYSQL_*`, `DATABASE_USERNAME`/`DATABASE_PASSWORD`, `DB_*`, and similar.
4. Nothing matched: ask the user with `ask_user_question`.

A complete set is provider, host, port, database, username, and secret. `sqlite`/`duckdb` need only the file path.

Prefer a local endpoint. A remote or production-looking host needs explicit user consent first.

## 2. Open a throwaway connection

```
CONF=/tmp/pi-scratchpad/$(date +%s)_sqlit
mkdir -p "$CONF"
export SQLIT_CONFIG_DIR=$CONF SQLIT_SKIP_KEYRING_PROBE=1

sqlit connections add postgresql --name q \
  --server "$PGHOST" --port "$PGPORT" --username "$PGUSER" \
  --database "$PGDATABASE" --password-command "cat"
```

- `SQLIT_CONFIG_DIR` keeps the throwaway `connections.json` out of `~/.config/sqlit`.
- `SQLIT_SKIP_KEYRING_PROBE=1` blocks the keyring/D-Bus probe.
- `--password-command "cat"` makes sqlit read the secret from its own stdin on every query. The secret is never written to disk or argv.

`postgresql` above is the provider token; others include `mysql`, `mariadb`, `mssql`, `sqlite`, `duckdb`. Run `sqlit connections add <provider> --help` for that provider's flags. File-based providers skip the secret: `sqlit connections add sqlite --name q --file-path "$DB_PATH"`.

## 3. Query

```
printf '%s\n' "$PGPASSWORD" | sqlit query -c q -o json -l 1000 -q "SELECT ..."
```

- The pipe is the secret. Feed it on every `query`; a missing pipe means an empty password.
- `-o json` for exact values, `-o table` for human display; `-l` sets the row limit (`-f <file>` runs a SQL file instead of `-q`).
- Non-zero exit or stderr means failure: report it, do not retry blindly.

Queries that mutate data (INSERT, UPDATE, DELETE, DDL) need explicit user confirmation first. Default to read-only SELECTs.

## 4. Clean up

When the session's queries are done: `rm -r "$CONF"`.

## Caveats

- Stdin carries one secret. If the connection also needs an SSH password, use `--password-command` for the database and a separate source for `--ssh-password-command`.
- Never pass the secret as a plain `--password` value; it leaks to `ps` and shell history.
