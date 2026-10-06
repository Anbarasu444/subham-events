# Event Planning Platform — Claude Code Starter

This folder is the project root for the Claude Code setup.

## Place your applications here

The repository expects:

```text
user_app/       # Put your existing Flutter User App template here
vendor_app/     # Put your existing Flutter Vendor App template here
admin_cms/      # Next.js + shadcn/ui Admin CMS (Next.js + shadcn/ui), created in its milestone
backend/        # NestJS REST API, created/expanded in its milestone
database/       # PostgreSQL migrations/schema
.claude/        # Claude governance, skills, agents, workflows and project state
```

`user_app/` and `vendor_app/` are intentionally empty placeholders in this starter ZIP. Replace their `.gitkeep` files by placing the actual existing Flutter projects there. Do not merge the two apps.

## Start with Claude Code
1. Extract this ZIP.
2. Place your existing User App project inside `user_app/`.
3. Place your existing Vendor App project inside `vendor_app/`.
4. Open the extracted root in Claude Code.
5. Tell Claude to read `CLAUDE.md` and `.claude/project/current-milestone.md`.
6. Begin only with M0/M1 governance and architecture.

## Development lock
The existence of `vendor_app/` does not authorize Vendor App development. The active milestone controls what Claude may change. User App must reach M23 freeze before Vendor App work begins.


## Technology Decisions

- User App: Flutter + GetX
- Vendor App: Flutter + GetX
- Admin CMS: Next.js + shadcn/ui
- Backend: NestJS REST API
- Database: PostgreSQL
- Authentication/Push: Firebase where required
- Vendor platform fees: Razorpay
