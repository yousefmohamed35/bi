## Auth API Contract – Mobile App

This document describes the **request/response format** the Flutter app uses for **Register** and **Login**, including device information fields.

---

## 1. Register

- **Method**: `POST`  
- **Path**: `/api/auth/register` (replace with actual backend path)

### Request body

```json
{
  "name": "string, required – full name (first + last)",
  "email": "string, required – unique email",
  "phone": "string, optional – Egyptian mobile, e.g. 01123456789",
  "password": "string, required",
  "password_confirmation": "string, required – must match password",
  "role": "string, optional – default 'student', can be 'instructor'",
  "student_type": "string, optional – 'online' or 'offline' when role = 'student'",

  "device_id": "string, required – UUID generated and stored on device",
  "device_name": "string, required – e.g. 'iPhone 15', 'Samsung Galaxy S24'",
  "platform": "string, required – 'Android' or 'iOS'",
  "fcm_token": "string, optional – FCM token for push notifications"
}
```

### Notes

- Exactly one logical device is identified by `device_id` and can be used to enforce **max devices per user**.
- `fcm_token` may be `null`/empty; backend should accept missing token without failing the request.

### Success response (example)

```json
{
  "success": true,
  "message": "Account created successfully",
  "data": {
    "token": "string – access token",
    "refresh_token": "string – refresh token",
    "user": {
      "id": 123,
      "name": "string",
      "email": "string",
      "phone": "string|null",
      "role": "student|instructor",
      "status": "ACTIVE|PENDING|BLOCKED"
    }
  }
}
```

On flows where new accounts are **PENDING** admin approval, backend can:

- Return `success: true`, `status: "PENDING"` and omit tokens, **or**
- Return `success: false` with an explanatory `message`.

### Error response (example)

```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "email": ["The email has already been taken."]
  }
}
```

---

## 2. Login

- **Method**: `POST`  
- **Path**: `/api/auth/login` (replace with actual backend path)

The app allows login via **email or phone**; only one of them will be sent per request.

### Request body

```json
{
  "email": "string, optional – when user logs in with email",
  "phone": "string, optional – when user logs in with phone",
  "password": "string, required",

  "device_id": "string, required – same UUID as stored on device",
  "device_name": "string, required – e.g. 'iPhone 15', 'Samsung Galaxy S24'",
  "platform": "string, required – 'Android' or 'iOS'",
  "fcm_token": "string, optional – FCM token for push notifications"
}
```

### Backend expectations

- Authenticate with either:
  - `email + password`, or
  - `phone + password`.
- Use `device_id`, `device_name`, `platform`, `fcm_token` to:
  - Create/update a **device/session** record.
  - Enforce a **maximum number of active devices per user** (1–2 devices) if required.
  - Store/update the FCM token for push notifications for this specific device.

### Success response (example)

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "string – access token",
    "refresh_token": "string – refresh token",
    "user": {
      "id": 123,
      "name": "string",
      "email": "string",
      "phone": "string|null",
      "role": "student|instructor",
      "status": "ACTIVE"
    }
  }
}
```

### Error response (example)

```json
{
  "success": false,
  "message": "Invalid credentials",
  "errors": {
    "email": ["These credentials do not match our records."]
  }
}
```

---

## 3. Device / Session Management (optional but recommended)

With the above payloads the backend can:

- Track devices by `device_id`, `device_name`, `platform`.
- Limit a user to **N active devices** (e.g. 1 or 2).
- Invalidate old sessions/devices when a new device logs in.
- Use `fcm_token` per device for precise push notifications.

