# Firebase Rules
Firebase Auth is the identity layer for Google and phone login. Guest browsing is allowed, but protected actions require authenticated identity. FCM is push delivery. Never ship Firebase service-account credentials to clients. Backend validates identity claims and maps users to PostgreSQL records.
