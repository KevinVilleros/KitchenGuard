# ADR 0004 — State management with Provider

## Status
Accepted

## Context

The mobile app must manage several state domains: PC connection, alarms,
standalone monitoring and UI tour.

## Decision

Use the **`provider`** package (`ChangeNotifier`) as the state-management
solution, with **one provider per domain**:

- `ServerProvider` — PC connection and discovery.
- `AlarmsProvider` — server alarms.
- `StandaloneProvider` — standalone monitoring.
- `TourController` — UI tour.

## Consequences

**Positive**
- Simple, widely adopted API.
- Low coupling: each domain is independent.
- Easy to test in isolation.

**Negative**
- No advanced declarative management (unlike Riverpod/Bloc).

**Neutral**
- Can be migrated to Riverpod later if complexity grows.
