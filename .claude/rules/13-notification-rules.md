# Notification Rules
Every meaningful user-impacting state change must be evaluated for notification. PostgreSQL notification records are the in-app source of truth; FCM is push delivery. Notifications must identify recipient, type, entity type/id, message, read state and creation time. Support deep-link/navigation metadata where useful. Avoid noisy pushes for purely internal technical events.
