# Zabisa Mobile Nawasena Design System

## Redesign direction

Phase 3.9.1 replaces the rejected Sakinah direction with **Nawasena**, an
enterprise-grade visual language built from confident cobalt, deep navy,
digital cyan and restrained warm gold. Islamic identity comes from meaningful
copy, an original young Quran learner mascot and subtle accessible motion—not
decorative density or changes to product flow.

This is a presentation-only redesign. API paths, query keys, state stores,
authentication, validation, navigation destinations, donation behavior and
backend authorization remain unchanged.

## Visual hierarchy

1. A short eyebrow establishes context.
2. One clear title carries the screen purpose.
3. Supporting copy explains privacy or the next action.
4. Cobalt anchors global actions while each service has a recognizable colour.
5. Two-column service cards replace the cramped four-column icon grid.
6. Cards group related information; semantic status colours remain reserved.
7. Gold is a premium accent, never body text or the sole status indicator.

## Design tokens

| Token group | Direction | Usage |
|---|---|---|
| Primary | `#1769E0`, dark `#0F4FB8`, deep `#082B69` | Global actions, links and hero surfaces |
| Primary soft | `#DCEAFF`, softer `#F0F6FF` | Selected surfaces and outlined actions |
| Digital | cyan `#18A9E6` | Connectivity, lightweight glow and digital cues |
| Accent | gold `#F4B942` | Premium emphasis and Islamic ornament only |
| Canvas | `#F4F7FC` | Cool low-glare enterprise background |
| Surface | white / cool white | Cards, fields and bottom navigation |
| Text | `#102A4C`, soft `#324A68`, muted `#687D99` | Three-level readable hierarchy |
| Semantic | success, warning, danger, info | Status and feedback only |
| Services | rose, indigo, blue, orange, teal, violet, coral, cyan | Unique and consistent service identity |

Typography uses the platform system font so Android and iOS scaling remains
native. The scale is 10, 12, 15, 19, 25 and 32sp with deliberately generous
line height. Spacing follows a 4dp base grid. Cards use 20dp corners, major
feature surfaces use 26–30dp corners, and buttons use 14dp corners.

## Component rules

- Global actions use cobalt. Donation uses rose, Kajian uses indigo, content
  uses blue/orange/violet, notifications use coral, and account uses cyan.
  Colour is paired with icon and text, so it is never the only meaning carrier.
- Minimum tap target is 48dp; primary button height is 54dp.
- Cards use one-pixel semantic borders and restrained elevation.
- Text fields use a warm surface, persistent label and explicit inline error.
- Bottom navigation has five unchanged destinations with a compact coloured
  focus capsule per destination while preserving every label.
- Loading, empty and error states remain explicit on every API screen.
- Icons continue to use reviewed local assets through `AppIcon`.

## Mascot and Islamic ambient motion

The Home hero uses an original, locally bundled illustration of an Indonesian
child respectfully holding a closed Quran. The cover intentionally has no
generated sacred text. Shared light geometry has a slow breathing motion using
React Native's built-in `Animated` driver. Motion never blocks touch input and
remains static when the operating system requests reduced motion.

## Screen structure

| Screen | Presentational structure |
|---|---|
| Login | Branded arch panel → contextual header → secure form card → development-only credential note |
| Home | Compact greeting → mascot hero → eight colour-coded unchanged actions → latest kajian → donation cards |
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
