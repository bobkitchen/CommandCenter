# Liquid Glass Design Guide for Command Center iOS App

## What is Liquid Glass?
Apple's new design language announced at WWDC 2025, shipping in iOS 26. It features translucent, glass-like UI elements that reflect and refract their background. It replaces the flat design era with fluid, dynamic materials.

## Key Principles
1. **Content over chrome** — glass surfaces should enhance, not compete with content
2. **Hierarchy through material** — use glass prominence to show what's interactive vs passive
3. **Consistency** — shapes, tinting, and spacing should align across the app
4. **Motion-responsive** — elements react to device movement (handled by the system)

## SwiftUI API Reference

### Basic Glass Effect
```swift
// Default capsule shape
Text("Label")
    .padding()
    .glassEffect()

// With specific shape
Text("Label")
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16))

// Available shapes: .capsule (default), .rect(cornerRadius:), .circle, .ellipse
```

### Glass Variants
```swift
// Regular (default) — standard frosted glass
.glassEffect(.regular)

// Clear — fully transparent, just refraction
.glassEffect(.clear)

// With tinting
.glassEffect(.regular.tint(.blue))
```

### Interactive Glass (for tappable elements)
```swift
// Responds to touch with scaling, bounce, shimmer
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
```

### GlassEffectContainer (REQUIRED when multiple glass elements coexist)
Glass cannot sample other glass. When you have multiple glass elements nearby, wrap them:
```swift
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        CardView()
            .glassEffect(in: .rect(cornerRadius: 16))
        CardView()
            .glassEffect(in: .rect(cornerRadius: 16))
    }
}
```

### Glass Button Styles
```swift
Button("Action") { }
    .buttonStyle(.glass)

Button("Primary") { }
    .buttonStyle(.glassProminent)
```

### Morphing Transitions
```swift
// Use glassEffectID with @Namespace for smooth morphing between states
@Namespace private var ns

view
    .glassEffect(in: .rect(cornerRadius: 16))
    .glassEffectID("card", in: ns)
```

### Availability Gating (REQUIRED)
ALWAYS gate with #available and provide fallback:
```swift
if #available(iOS 26, *) {
    content
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
} else {
    content
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

### Modifier Order (IMPORTANT)
Apply `.glassEffect()` LAST — after all layout and visual modifiers:
```swift
Text("Hello")
    .font(.headline)        // appearance first
    .foregroundStyle(.white) // appearance first
    .padding()               // layout first
    .glassEffect()           // glass LAST
```

## How to Apply to Command Center

### Tab Bar
- Use the system tab bar — iOS 26 automatically applies Liquid Glass to it

### Dashboard Cards
- Each widget card: `.glassEffect(in: .rect(cornerRadius: 20))`
- Wrap the card grid in `GlassEffectContainer`
- Use a rich background (gradient or subtle pattern) so the glass has something to refract
- Crisis cards: tint with status color — `.glassEffect(.regular.tint(.red))` for critical

### Chat Bubbles
- Assistant messages: `.glassEffect(.regular, in: .rect(cornerRadius: 18))` — subtle frosted glass
- User messages: solid accent blue (NOT glass — glass would make them hard to read)
- Chat input bar: `.glassEffect(in: .rect(cornerRadius: 22))`

### Navigation Bar
- Use system navigation bar — iOS 26 applies glass automatically
- Or use `.toolbarBackgroundVisibility(.visible, for: .navigationBar)` with glass material

### File Browser
- File rows: clean, minimal — no glass on individual rows (too busy)
- Toolbar/breadcrumbs: glass effect
- File preview modal: glass background

### Overall Background
Use a subtle gradient or mesh gradient as the app background — this gives the glass material something to refract:
```swift
LinearGradient(
    colors: [Color(hex: "#0d1117"), Color(hex: "#1a1f2e"), Color(hex: "#0d1117")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.ignoresSafeArea()
```

## Color Scheme with Liquid Glass
The dark theme still applies, but glass surfaces replace solid card backgrounds:
- Background: Dark gradient (not flat #0d1117)
- Glass surfaces: system glass material (adapts automatically)
- Text on glass: .primary (system handles legibility)
- Accent: #58a6ff (use for interactive elements, user chat bubbles)
- Status colors: #3fb950 (success), #d29922 (warning), #f85149 (danger)

## Performance Notes
- Glass compositing has GPU cost — don't apply to hundreds of views
- Use GlassEffectContainer to batch compositing
- In chat, consider only applying glass to visible messages (LazyVStack handles this)
