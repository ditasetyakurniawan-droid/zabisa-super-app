# Zabisa Mobile Design System

## Direction
Zabisa uses a modern sky-blue visual language: trustworthy, calm, clean and suitable for a digital-service super-app. The direction may feel familiar to Indonesian financial apps, but Zabisa does not copy another product's branding, layout, iconography, or trade dress.

## Semantic colours
- `primary`: main actions, selected tab, links, key values.
- `primaryDark` / `primaryDeep`: hierarchy and high-emphasis blue.
- `primarySoft` / `primarySofter`: icon backgrounds, selected surfaces, unread states.
- `sky`: progress and secondary visual highlight.
- `background`: low-contrast app canvas.
- `surface`: cards and fields.
- `success`, `warning`, `danger`: semantic status only.

Never hard-code a brand colour in feature screens. Add a semantic token instead.

## UI rules
1. One dominant CTA per card/screen section.
2. Minimum interactive height 48dp, primary button 52dp.
3. API screens implement loading, success, empty and error states.
4. Private student data never appears in public screens.
5. Text remains readable with system font scaling.
6. Use local icon assets through `AppIcon`; do not scatter icon package usage.
7. Dates/currency use `src/utils/format.ts` for Indonesian presentation.
8. Development-only seed labels stay behind `__DEV__`.

## Bottom navigation
Five persistent destinations: Beranda, Kajian, Donasi, Notifikasi, Akun. Secondary/private flows use the stack navigator.
