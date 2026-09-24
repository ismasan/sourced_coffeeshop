# Sourced Coffee

A coffee shop point-of-sale demo built with [Sidereal](https://ismasan.github.io/sidereal/)
(server-driven reactive web framework) on a [Sourced](https://github.com/ismasan/sourced/tree/ccc)
event-sourcing backend.

https://github.com/user-attachments/assets/3f937ffa-6867-40f1-93f0-30497486f599


Cashiers start orders and add products from a catalog, baristas prepare the items, a
simulated payment provider confirms payment, and a small automation delivers the order once it
is both made and paid. Every screen updates live over Server-Sent Events, and every order page
shows the full command/event history of the order, which you can step through to see the order
as it was at any point.

## How it works

- **Commands** posted from the browser are validated and appended to a SQLite event log.
- **Deciders** (`Order`, `Payment`) rebuild an order's state from its own messages, decide each
  command and emit events. Reactions chain the workflow: the last fulfilled item fulfils the
  order, a started payment hands over to the payment provider, a confirmed payment reports back.
- **Projectors** maintain the read models behind the list pages (`OrderListings`,
  `PaymentListings`) and the deliverables board, which also schedules automatic delivery.
- **Pages** are Phlex components that subscribe to pubsub channels and are re-rendered and
  morphed into the DOM by Datastar whenever a relevant event or projection commits.

The Sourced runtime (deciders, projectors, automations) runs inside the Falcon web process, on
the elected leader worker. There is nothing else to run.

## Requirements

- Ruby 3.2 or newer (developed on 4.0)
- A C compiler toolchain, for gems with native extensions (Xcode Command Line Tools on macOS,
  `build-essential` on Debian/Ubuntu). SQLite itself is bundled with the `sqlite3` gem.
- `git`, since some gems are installed from GitHub

Single machine only: cross-process messaging uses a unix socket and a file lock under `storage/`.
Keep the checkout path reasonably short, since unix socket paths are limited to about 100
characters (the app refuses to boot with a clear error otherwise).

## Setup

```bash
git clone <this repo>
cd sourced_coffeeshop
bundle install
```

Create your local environment file and give it a session secret. Rack wants at least 64 bytes:

```bash
cp .env.example .env
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'   # paste the output as SESSION_SECRET in .env
```

Create the database (Sourced's tables plus the read models), in `storage/coffeeshop.db` by default:

```bash
bundle exec rake db:migrate
```

## Running

```bash
bundle exec falcon host
```

Then open <http://localhost:9292>, pick a username and start an order from the **Cashier**
page. Open the **Barista** page in another window to prepare and deliver it. The Sourced
dashboard (event log, consumer groups, topology) is at <http://localhost:9292/sourced>.

`HOST`, `PORT` and `COUNT` (Falcon worker processes) can be changed in `.env`.

### Reloading on code changes

```bash
bin/dev
```

Runs `falcon host` and, whenever a Ruby or config file changes, sends `SIGHUP` to Falcon, which
forks fresh workers that load the app from scratch. Needs [watchexec](https://github.com/watchexec/watchexec)
(`brew install watchexec`) or `fswatch` on the `PATH`; without either it just runs the server.
Browsers reconnect their SSE streams and catch up automatically. Changes to `.env` still need a
full restart.

## Tests

```bash
bundle exec rspec
```

Decider and projector specs use Sourced's Given/When/Then helpers against an in-memory store;
no server or database file is needed.

## Other tasks

```bash
bundle exec rake db:reset                # wipe the event log and read models
bundle exec rake console                 # IRB with the app loaded
bundle exec rake db:sourced_migration    # regenerate the Sourced tables migration
```

## Layout

| Path | What |
| --- | --- |
| `app.rb` | The Sidereal app: routes, exposed commands, pages, channel routing |
| `boot.rb` | Code loading, Sourced and Sidereal configuration |
| `domain/` | `Order` and `Payment` deciders, the projectors |
| `ui/` | Layout, pages and components (Phlex) |
| `lib/` | Product catalog (`config/catalog.yml`) and shared types |
| `db/migrations/` | Sequel migrations for the event store and read models |
| `spec/` | RSpec suite |
