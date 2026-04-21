# Login & Register API Contract (Mobile App -> Backend)

This document describes the exact auth payloads currently sent by the Flutter app so backend can implement/align endpoints safely.

Base URL: `https://bimaristan.anmka.com/api`

---

## 1) Login

- **Method:** `POST`
- **Endpoint:** `/auth/login`
- **Auth required:** No

### Request Body

```json
{
  "identifier": "user@email.com or 01xxxxxxxxx",
  "password": "user_password",
  "deviceFingerprint": "fcm_token_or_device_id",
  "fcm_token": "optional_fcm_token"
}
```

### Field Notes

- `identifier` (required): email OR phone (single field for both).
- `password` (required).
- `deviceFingerprint` (usually sent): app sends FCM token if available, otherwise device id.
- `fcm_token` (optional but commonly sent).

### Success Response (expected by app)

```json
{
  "success": true,
  "message": "optional",
  "data": {
    "user": {
      "id": "string-or-number",
      "name": "string",
      "email": "string",
      "role": "student | instructor | teacher"
    },
    "accessToken": "jwt_or_token_string",
    "refreshToken": "refresh_token_string",
    "expires_at": "optional_datetime"
  }
}
```

### Token compatibility supported by app

The app can read token from these keys (priority order):

- `data.accessToken` (preferred)
- `data.token`
- `data.access_token`
- `token` (root level fallback)

For refresh token:

- `data.refreshToken` (preferred)
- `data.refresh_token`
- `refreshToken` (root level fallback)

### Error Response (recommended)

```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

Or validation format:

```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "identifier": ["Identifier is required"],
    "password": ["Password is required"]
  }
}
```

---

## 2) Register

- **Method:** `POST`
- **Endpoint:** `/auth/register`
- **Auth required:** No

### Request Body

```json
{
  "name": "First Last",
  "email": "user@email.com",
  "password": "secret123",
  "confirmPassword": "secret123",
  "accept_terms": true,
  "role": "student",
  "device_id": "stable_device_id",
  "device_name": "SM-G998B",
  "platform": "Android",
  "email_verified_token": "optional_token_if_required",
  "phone": "01xxxxxxxxx",
  "username": "username_123",
  "whatsappNumber": "+201xxxxxxxxx",
  "nationalId": "14_digit_id",
  "student_type": "online | offline",
  "fcm_token": "optional_fcm_token",
  "avatar": "optional_uploaded_image_url"
}
```

### Field Notes

- Required in app flow:
  - `name`, `email`, `password`, `confirmPassword`, `accept_terms`, `role`, `device_id`, `device_name`, `platform`
- Optional:
  - `phone`, `username`, `whatsappNumber`, `nationalId`, `student_type`, `fcm_token`, `avatar`, `email_verified_token`
- `role` default from app is `student` (can be `instructor` if needed).
- `student_type` is sent only for student role.
- `accept_terms` is boolean.

### Success Response (minimum needed by app)

```json
{
  "success": true,
  "message": "Account created successfully",
  "data": {
    "id": "string-or-number",
    "name": "string",
    "email": "string",
    "role": "student"
  }
}
```

> Note: For register, app expects user data directly in `data` (not necessarily `data.user`).

### Error Response (recommended)

```json
{
  "success": false,
  "message": "Validation error",
  "errors": {
    "email": ["Email already exists"],
    "username": ["Username already exists"]
  }
}
```

---

## 3) Email verification required by current register/login flow

The app currently uses these endpoints too (important for full registration journey):

### 3.1 Send verification code

- **Method:** `POST`
- **Endpoint:** `/auth/register/send-code`
- **Body:**

```json
{
  "email": "user@email.com"
}
```

- **Expected success response:**

```json
{
  "success": true,
  "message": "Code sent",
  "data": {
    "verificationToken": "token_string"
  }
}
```

### 3.2 Verify code

- **Method:** `POST`
- **Endpoint:** `/auth/register/verify-code`
- **Body:**

```json
{
  "email": "user@email.com",
  "code": "123456",
  "verificationToken": "optional_token_from_send_code"
}
```

- **Expected success response:**

```json
{
  "success": true,
  "message": "Email verified successfully"
}
```

---

## 4) Implementation notes for backend team

- Return consistent JSON with top-level `success` and `message`.
- Prefer HTTP status codes aligned with errors (`400`, `401`, `422`, `500`) while still returning JSON body.
- Keep key names exactly as documented (especially `confirmPassword`, `accept_terms`, `deviceFingerprint`, `email_verified_token`).
- For login response, include `data.user.role` because app routes user by role.

