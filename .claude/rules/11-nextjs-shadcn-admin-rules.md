# Admin CMS (Next.js + shadcn/ui) Rules
Admin CMS (Next.js + shadcn/ui) is a Next.js CMS, not a Flutter app. Use role-based access control. Admin UI can manage categories, fees, vendor review, users, events, bookings, payments, notifications, content and reports. Backend remains authoritative; never rely on UI-only permission checks.


## shadcn/ui

The Admin CMS uses shadcn/ui as the UI component foundation. Prefer accessible, composable shadcn/ui components. Do not introduce a second component library without explicit approval. Keep Tailwind/shadcn conventions consistent across the CMS.
