# Screenshot swap procedure

`DeviceFrame` (`src/components/DeviceFrame.astro`) renders a labelled placeholder at the
App Store 1320x2868 aspect until real screenshots land. To swap one in, drop a PNG here with
the exact filename below and pass it as the `src` prop on the matching `DeviceFrame` usage.

## Expected filenames

| # | Filename | Screen | Used on |
|---|---|---|---|
| 1 | `01-dashboard.png` | Dashboard, high UV reading | `/`, `/tr` (hero) |
| 2 | `02-skin-type.png` | Skin type quiz result | `/`, `/tr`, `/features`, `/tr/ozellikler` |
| 3 | `03-safe-time.png` | Safe-time card and advice | `/features`, `/tr/ozellikler` |
| 4 | `04-timer.png` | Timer running | `/features`, `/tr/ozellikler` |
| 5 | `05-uv-forecast.png` | UV forecast chart | `/features`, `/tr/ozellikler` |
| 6 | `06-tan-tracker.png` | Tan tracker calendar and streak | `/features`, `/tr/ozellikler` |

Capture at 1320x2868 (the 6.9" App Store requirement) per the procedure in `APPSTORE.md`.
Turkish device language is fine for both locales' marketing screenshots; the site copy is what
changes per locale, not the screenshot content.

## To swap a placeholder for a real image

1. Add the PNG here with the filename from the table above.
2. Open the page that uses it and add `src="01-dashboard.png"` (etc.) to the `<DeviceFrame>`
   call.
3. Rebuild (`pnpm build`) and check the frame at 320px, 768px and 1440px: the component crops
   to `object-fit: cover` inside the fixed 1320:2868 aspect box, so verify nothing important in
   the screenshot sits outside a safe centre crop.

Until a filename is supplied, the frame renders its designed placeholder (index mark, screen
name and a short state hint), never a plain coloured rectangle.
