# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A **coffee shop POS demo** built with **Sidereal** (server-driven reactive web framework) on a
**Sourced** ("ccc" branch: stream-less, partition-based event sourcing) backend. Pages are Phlex
components pushed to the browser over SSE via Datastar; forms post commands; deciders and
projectors process them asynchronously on the Sourced runtime, which runs inside the Falcon
web process.

## Architecture

### Request / message flow

```
Browser form → POST /commands (Sidereal::App, validates + stamps session user)
  → Sourced store (SQLite, key-pair indexed log)
  → Order / Payment deciders (partitioned by order_id / payment_id) emit events
  → Projectors update read models; reactions dispatch follow-up commands
  → Sidereal::Integrations::Sourced publishes events + `Projected` signals to pubsub
  → Pages subscribed on /updates/<channel> re-render and morph the DOM
```

### Layers

**Domain** (`domain/`, all registered in `boot.rb`):
- `Order` — `Sourced::Decider`, `partition_by :order_id`. Commands, events, `State`, guards and two
  reactions (auto-fulfil order, hand over to `Payment`). Commands that don't apply are silent no-ops
  (a raise would stop the consumer group).
- `Payment` — `Sourced::Decider`, `partition_by :payment_id`. Simulates a provider with a scheduled
  `Confirm` command (`dispatch(...).at(...)`), then reports back with `Order::ConfirmPayment`.
- `OrderListings`, `PaymentListings` — `Projector::StateStored` writing `orders` / `payments` tables.
- `Deliverables` — `Projector::EventSourced` (fulfilled + paid, not delivered) writing the
  `deliverables` table and scheduling `Order::DeliverOrder` as an automation.
- Every projector auto-publishes a `<Klass>::Projected` signal (from `partition_by`) that pages react to.

**UI** (`ui/`, Phlex):
- `Layouts::Layout` — nav + `#modal` slot; extends `Sidereal::Components::Layout` (Datastar script,
  page signals, SSE init).
- `Pages::*` — `Sidereal::Page` subclasses: `path`, `on(Event...)` reactions, `self.load(params, ctx)`,
  `channel_name`. List pages subscribe to `shop.>`; order pages to `shop.orders.<id>`.
  `OrderPage` reads the order's partition straight from the store (commands + events) for the history
  sidebar and supports frozen snapshots at `/orders/:id/:step`.
- `Components::*` — reusable pieces (Phlex kit). Forms use Sidereal's `command Klass, key: do |f| ... end`.
- `ViewHelpers` — helpers shared by components and pages.

**App** (`app.rb`): `Sidereal::App` subclass — session, `before` login guard, `before_command`
(stamps `producer` + `username` metadata), `channel_name` resolver, login/logout routes, modal
routes (SSE responses patching `#modal`), snapshot route, `handle` for browser-exposed commands,
`page` registrations.

**Boot** (`boot.rb`): Zeitwerk eager-loads `lib/`, `domain/`, `ui/`; configures Sourced (SQLite at
`DATABASE_PATH`, default `storage/coffeeshop.db`); registers reactors; wires Sidereal
(`use_file_system!` for cross-process pubsub/elector + `use Sidereal::Integrations::Sourced`).
Skipped in `TEST` (specs use an in-memory store).

## Key Technologies

- **Sidereal** (local path gem) + **Sourced ccc** + **sourced-ui** dashboard (mounted at `/sourced`)
- **Phlex 2** + **Datastar 1.0** (attributes: `data-on:click`, `data-bind`, `data-show`, `data-signals__ifmissing`)
- **SQLite** via **Sequel** (event log + read models in one file), **Plumb 0.3** types, **Money** gem
- **Falcon** (0.57+, matching Sidereal's Falcon environment; older Falcon calls `Service#run` with two args and fails to boot), **Zeitwerk**

## Development Commands

```bash
bundle install
bundle exec rake db:migrate          # Sourced tables + read models (db/migrations)
bundle exec falcon host              # http://localhost:9292 (HOST/PORT/COUNT from .env)
bundle exec rspec                    # decider + projector specs (Sourced GWT helpers)
bundle exec rake db:reset            # wipe the log and read models
bundle exec rake console             # IRB with boot.rb loaded
bundle exec rake db:sourced_migration  # regenerate the Sourced tables migration
```

The Sourced runtime runs on the elected leader Falcon worker only; other workers serve pages and
append commands. Set `COUNT=1` for a single process.

## Development Notes

- **No hot reloading**: restart `falcon host` after code changes (workers load the app fresh on fork).
  Kill stray workers with `lsof -tiTCP:9292 -sTCP:LISTEN | xargs kill`.
- **Zeitwerk naming**: `ui/view_helpers.rb` must define `ViewHelpers`; acronyms need an inflection.
- **Testing projectors**: `StateStored` projectors evolve only the `when` batch; `EventSourced`
  projectors evolve the `given` history, which at runtime includes the batch, so put the triggering
  event in both `given` and `when`.
- **Money**: prices travel as Integer cents in messages; `Money` objects live in state and views.
- **Static assets**: `public/css/main.css`, `public/images/`; served by `Rack::Static` in `config.ru`.
