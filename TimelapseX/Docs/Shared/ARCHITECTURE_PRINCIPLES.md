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
- Keep each module, view, and view model in its own file when practical
- If a file must contain more than one type, the filename should still
  reflect the primary type it owns
- Shared utilities live in Core/
- Design tokens live in DesignSystem/

## Naming
- Use clear, feature-aligned names for folders and files
- Prefer PascalCase for Swift types and keep file names aligned with the
  primary type in the file
- Avoid ambiguous names that hide the module's responsibility

Architecture should optimize for:
1. Readability
2. Change safety
3. Deletion ease
