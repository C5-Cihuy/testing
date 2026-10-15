# SwiftUI Components Reference

## Data-only components

```swift
import SwiftUI

struct PlayerChipView: View {
    let name: String
    let chips: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).lineLimit(1)
            Text(chips, format: .number)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PlayerChipView(name: "Test Player", chips: 1_250)
}
```

The component receives already-appropriate display data. Do not load or derive
business data inside it.

## Actions and callbacks

```swift
struct ActionButtonView: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isEnabled)
        .accessibilityHint("Performs \(title.lowercased()) action")
    }
}

#Preview {
    ActionButtonView(title: "Call", isEnabled: true, action: {})
        .padding()
}
```

The parent owns selection and navigation behavior:

```swift
PlayerRowView(player: player, isActive: player.id == selectedID) {
    selectedID = player.id
}
```

Prefer closures over environment dependencies so the same component can be used
on multiple screens with different behavior.

## Configuration-driven variation

```swift
struct PotDisplayView: View {
    struct Configuration {
        var amount: Decimal
        var title = "Pot"
        var isHighlighted = false
        var showsProgress = false
    }

    let configuration: Configuration

    var body: some View {
        VStack {
            Text(configuration.title).font(.caption)
            Text(configuration.amount, format: .currency(code: "USD"))
                .font(.title3)
        }
        .padding()
        .background(.yellow.opacity(configuration.isHighlighted ? 0.15 : 0.05))
    }
}

#Preview {
    PotDisplayView(configuration: .init(amount: 1_250, isHighlighted: true))
}
```

Use configuration factory helpers for common variants, but do not turn the
configuration into a container for business rules.

## Composition and states

Compose focused components (`CardView`, `PlayerChipView`, `PlayerSeatView`) so a
design change remains local. Keep screen-level branching in the feature view:

```swift
@ViewBuilder
private var content: some View {
    if isLoading && items.isEmpty {
        LoadingView(title: "Loading...")
    } else if items.isEmpty {
        EmptyStateView(title: "No Items", message: "Try again", action: {})
    } else {
        itemList
    }
}
```

`LoadingView` and `EmptyStateView` render supplied state and callbacks; they do
not decide when loading starts or what an empty result means.

Avoid nested `ScrollView`/`List` in reusable components. The feature View owns
the scrolling container.

## Theme and accessibility

Centralize shared values in a theme namespace:

```swift
enum Theme {
    static let cornerRadius: CGFloat = 12
    static let contentPadding: CGFloat = 16

    enum Color {
        static let primaryText = SwiftUI.Color.primary
        static let accent = SwiftUI.Color.orange
    }
}
```

At the component boundary, make visual objects understandable to VoiceOver:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(rank) of \(suit)")
```

Add action hints and traits where they clarify interaction. Do not duplicate
labels already provided by child controls.

## Previews and organization

Use named previews for meaningful variants:

```swift
#Preview("Default") { PlayerChipView(name: "Player", chips: 50) }
#Preview("Long name") { PlayerChipView(name: "A Very Long Player Name", chips: 0) }
```

Previews use deterministic mock data and never call services. Organize files as:

```text
Views/
├── FeatureView.swift
└── Components/
    ├── Theme.swift
    ├── PlayerChipView.swift
    ├── PlayerRowView.swift
    ├── EmptyStateView.swift
    └── LoadingView.swift
```

Use one primary component type per file. Keep display helpers in files such as
`Player+Formatting.swift` rather than embedding formatting decisions in views.

## Pitfalls

- Do not add `@State` to a component unless it truly owns local, reusable UI
  interaction; prefer parent-provided state and bindings.
- Avoid parameter sprawl; use `Configuration` or split the component.
- Do not put network/database access or ViewModel references in components.
- Do not hide scrolling inside reusable content.
- Do not omit previews or use live data in previews.
