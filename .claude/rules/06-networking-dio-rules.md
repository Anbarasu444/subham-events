# Dio/API Rules
All HTTP access goes through the API/service layer. Centralize base URL, timeouts, interceptors, authentication, error mapping and logging. Never call Dio directly from widgets. Use typed request/response models and pagination where appropriate.
