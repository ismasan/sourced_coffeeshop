# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Sinatra-based coffee shop POS system** demonstrating **event sourcing architecture** with modern Ruby patterns. The application uses Phlex components with Datastar for reactive UI updates.

## Architecture

### Event Sourcing Pattern
- **Commands** trigger business logic and generate **Events**
- **Events** are stored and used to rebuild application state
- **Projectors** create read-optimized views from events
- **Actors** handle domain logic and command processing

### Layer Structure

**Domain Layer** (`domain/`):
- `Order` - Main business actor handling order commands/events
- `OrderListings` - Projector creating read views from order events

**UI Layer** (`ui/`):
- **Layouts** (`ui/layouts/`) - Page structure and navigation
- **Pages** (`ui/pages/`) - Full page components 
- **Components** (`ui/components/`) - Reusable UI elements
- All UI uses **Phlex** component system with **Datastar** for reactivity

**Application** (`app.rb`):
- Sinatra routes with session-based authentication
- Command processing via POST `/commands` endpoint
- Integration with Sourced event sourcing framework

## Key Technologies

- **Sinatra 4.0** + **Phlex 2.0** for component-based web development
- **Sourced** (custom gem) for event sourcing framework
- **Datastar** for frontend reactivity and Server-Sent Events
- **PostgreSQL** + **Sequel** for persistence
- **Zeitwerk** for code loading

## Development Commands

**Start Application:**
```bash
bundle exec rackup -p 4567
```

**Start Background Workers:**
```bash
bundle exec ruby bin/workers.rb
```

**Install Dependencies:**
```bash
bundle install
```

## Application Flow

1. **Authentication**: Users log in via `/login` (session-based)
2. **Command Processing**: UI sends commands to `/commands` endpoint
3. **Event Generation**: Commands generate events stored in event store
4. **State Rebuilding**: Projectors consume events to build read models
5. **UI Updates**: Datastar provides real-time updates via SSE

## File Patterns

- **Actors**: Handle commands and generate events (`domain/order.rb`)
- **Projectors**: Build read models from events (`domain/order_listings.rb`)
- **Components**: Phlex classes in `ui/components/`
- **Pages**: Full page Phlex components in `ui/pages/`
- **Layouts**: Page templates in `ui/layouts/`

## Development Notes

- **Hot Reloading**: rack-unreloader handles code reloading in development
- **Auto-loading**: Zeitwerk manages file loading conventions
- **Asset Hashing**: CSS files use content hashing in production
- **Mobile-First**: UI designed with responsive mobile experience