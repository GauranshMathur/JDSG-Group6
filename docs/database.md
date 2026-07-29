# Database

The app runs on **SQLite** by default, so a fresh checkout boots with no services. Nothing in
the application code knows which database it is talking to: migrations use standard Rails
column types and every query goes through Active Record.

**Switching to PostgreSQL:**

```bash
# 1. Install the pg gem (kept out of the default bundle so plain installs need no libpq)
cd web && bundle config set --local with postgres && bundle install

# 2. Start Postgres
docker compose -f infra/docker/docker-compose.yml up -d

# 3. Point the app at it
export DATABASE_URL=postgres://twitter_clone:twitter_clone@localhost:5432/twitter_clone_development

# 4. Create the schema
bin/rails db:prepare
```

`DATABASE_URL` overrides every setting in `config/database.yml`, adapter included, so no file
needs editing. Unset it to go back to SQLite.

Production is expected to run on PostgreSQL (RDS) configured entirely through `DATABASE_URL`.
