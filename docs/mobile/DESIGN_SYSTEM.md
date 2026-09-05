# Zabisa Mobile Sakinah Design System

## Redesign direction

Phase 3.9 evolves the earlier sky-blue baseline into **Sakinah**: a calm,
modern visual language built from emerald, warm ivory and restrained gold.
Islamic identity is expressed through lightweight geometric arches, stars and
ambient motion—not through decorative density or changes to the product flow.

This is a presentation-only redesign. API paths, query keys, state stores,
authentication, validation, navigation destinations, donation behavior and
backend authorization remain unchanged.

## Visual hierarchy

1. A short eyebrow establishes context.
2. One clear title carries the screen purpose.
3. Supporting copy explains privacy or the next action.
4. One dominant emerald action appears in each decision area.
5. Cards group related information; status colors are reserved for status.
6. Gold is an ornamental accent, never the primary action color.

## Design tokens

| Token group | Direction | Usage |
|---|---|---|
| Primary | `#087A68`, dark `#075F54`, deep `#063F3A` | Every primary action, link and selected destination |
| Primary soft | `#DDF3ED`, softer `#F1FAF7` | Icon containers, selected surfaces and outlined actions |
| Accent | `#D6A94F`, dark `#946D21` | Islamic ornament and small emphasis only |
| Canvas | `#F7F8F3` | Warm low-glare application background |
| Surface | white / warm white | Cards, fields, floating navigation |
| Text | `#17332F`, soft `#3C5853`, muted `#687D78` | Three-level readable hierarchy |
| Semantic | success, warning, danger, info | Status and feedback only |

Typography uses the platform system font so Android and iOS scaling remains
native. The scale is 10, 12, 15, 19, 25 and 32sp with deliberately generous
line height. Spacing follows a 4dp base grid. Cards use 22dp corners, major
feature surfaces use a 42dp arch radius, buttons use 16dp corners.

## Component rules

- All action buttons use the same emerald brand family. Secondary actions use
  the same emerald border/text on a soft surface; destructive meaning is shown
  in confirmation copy or status, not by inventing another brand button.
- Minimum tap target is 48dp; primary button height is 54dp.
- Cards use one-pixel semantic borders and restrained elevation.
- Text fields use a warm surface, persistent label and explicit inline error.
- Bottom navigation has five unchanged destinations and floats above the warm
  canvas while preserving labels.
- Loading, empty and error states remain explicit on every API screen.
- Icons continue to use reviewed local assets through `AppIcon`.

## Islamic ambient motion

The shared header and hero use an original geometric arch/star ornament with a
slow vertical breathing motion. It uses React Native's built-in `Animated`
driver, does not block touch input and is hidden from accessibility traversal.
When the operating system requests reduced motion, the animation remains
static. No animation waits on API data or changes navigation/state.

## Screen structure

| Screen | Presentational structure |
|---|---|
| Login | Branded arch panel → contextual header → secure form card → development-only credential note |
| Home | Greeting identity card → animated service hero → eight unchanged quick actions → latest kajian → donation cards |
| Kajian | Context header → icon-led event cards → unchanged detail navigation |
| Donation | Context header → optional history → icon-led campaign cards → progress → unchanged checkout |
| Notifications | Context header → unread summary → semantic notification cards |
| Account | Context header → identity card → guardian entry point → device-security action |
| Guardian | Privacy context → three summary cards → Tahfidz → grades → attendance → reports |
| Detail screens | Decorated context card → information card/content → unchanged actions |

## Accessibility and acceptance

- Text must remain readable at a larger Android font setting.
- Interactive controls need a semantic role/label and at least 48dp target.
- Contrast must remain understandable without relying on color alone.
- Motion must honor reduced-motion preference.
- No private student data may appear before backend-approved authentication.
- Physical-device acceptance must cover login, Home, guardian data, donation,
  kajian, notifications, empty/error states and back navigation.
