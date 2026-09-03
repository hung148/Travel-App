---
version: 1.0.0
name: Travel App Editorial Planner
description: A warm, photographic travel journal paired with a calm and highly usable planning workspace.
---

# Travel App Design System

## Principles

1. **Destination first:** photography and place names carry the strongest visual weight.
2. **One clear next step:** each section has one dominant action; secondary actions remain available without competing.
3. **Calm confidence:** motion is brief and functional, surfaces are light, and decoration never obscures planning data.
4. **Recognition over recall:** preserve trip context, selected destinations, costs, and progress throughout the flow.
5. **Accessible by default:** 48px targets, persistent labels, visible focus, text scaling, semantic status, and no color-only meaning.

## Color Tokens

- `canvas`: `#FFFFFF` — application background.
- `surface`: `#FAF7F4` — cards and grouped content.
- `surface-muted`: `#F4EDE8` — fields, chips, and quiet emphasis.
- `ink`: `#1C1816` — primary text.
- `ink-muted`: `#6F5B50` — supporting text.
- `brand`: `#5A3E32` — selection, focus, and travel identity.
- `brand-soft`: `#EADBD1` — selected backgrounds.
- `outline`: `#8B6B59` — interactive boundaries and focus support.
- `outline-soft`: `#BAA397` — card grouping.
- `action`: `#241C18` — primary actions.
- Semantic success, warning, and error always include an icon and text label.

## Typography

- Display and major section headings: editorial serif, 24–48px, 1.2–1.3 line height.
- UI, labels, metadata, and body: platform sans-serif, minimum 16px for essential content.
- Uppercase eyebrow labels are used sparingly with wider tracking.
- Body copy should remain within a comfortable reading measure and scale with system accessibility settings.

## Spacing and Shape

- Base unit: 8px.
- Scale: 4, 8, 12, 16, 24, 32, 48, 64.
- Related content uses 8–16px; separate sections use 24–32px.
- Cards: 24–28px radius. Inputs: 18px radius. Buttons and chips: pill shape.
- Mobile page margins: 16px. Tablet: 24px. Desktop: 32px with a bounded content width.

## Components

- **Primary button:** dark espresso fill, white label, minimum height 48px.
- **Secondary button:** light surface, visible brown outline, dark label.
- **Input:** persistent visible label, pale surface, strong focused outline, inline error recovery.
- **Place card:** image first, then name, role/time metadata, price last. Missing imagery uses a labeled icon fallback.
- **Status:** icon + concise text + semantic color; never color alone.
- **Dialog:** scroll-safe, keyboard dismissible, focus contained and returned to its trigger.

## Responsive Behavior

- Below 640px: single-column content and full-width primary actions.
- 640–1023px: reflow secondary panels below the core planning task.
- 1024px and above: use two-column layouts only where both columns remain independently useful.
- Maps may retain bounded two-dimensional interaction; all other content must reflow without horizontal scrolling.
- Layouts must tolerate 200% text scaling without clipping essential controls.

## Motion

- `instant`: 80ms for tiny feedback.
- `fast`: 140ms for presses and selection.
- `standard`: 220ms for component state changes.
- `slow`: 320ms for dialogs and major panels.
- Prefer opacity and color transitions. Avoid parallax, autoplay, full-screen scaling, and decorative looping.
- When reduced motion is requested, transitions become effectively immediate while progress indicators remain available.

## Do / Don't

- Do emphasize destinations, itinerary sequence, total cost, and the next action.
- Do use actual place photography when available with resilient placeholders.
- Do keep labels visible and errors next to the field that needs attention.
- Don't introduce isolated colors, radii, or animation durations outside this system.
- Don't use individual retail stores as shopping destinations; show actual malls only.
- Don't hide essential actions behind hover, long press, gesture-only, or color-only interactions.
