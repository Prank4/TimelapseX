# Architecture Principles

## Primary Pattern
- SwiftUI + MVVM
- Feature-based folder structure

## Non-Negotiables
- No business logic in Views
- No massive ViewModels
- No global singletons
- No premature abstractions

## Data Flow
SwiftData
 → ViewModel
   → SwiftUI View

Views observe state. They do not compute it.

## State Management
- Single source of truth
- Derived values are computed, not stored
- Persistence models are dumb

## Modularity
- Features are isolated
- Shared utilities live in Core/
- Design tokens live in DesignSystem/

Architecture should optimize for:
1. Readability
2. Change safety
3. Deletion ease

