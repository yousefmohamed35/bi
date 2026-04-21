# Registration Steps Contract (Mobile <-> Backend)

This document reflects the exact required flow:

1. User sends full registration data first.
2. Backend validates data and creates user with email **not active yet**.
3. Backend sends verification code.
4. User verifies email.
5. Backend activates account after successful verification.

---

## Step 1: Register data + create inactive account

### Endpoint
`POST /auth/register`

### Request Example (all fields used by mobile)
```json
{
  "name": "Ahmed Ali",
  "email": "ahmed.ali@example.com",
  "username": "ahmed_ali",
  "phone": "01012345678",
  "whatsappNumber": "+201012345678",
  "nationalId": "29901011234567",
  "password": "123456",
  "confirmPassword": "123456",
  "accept_terms": true,
  "role": "student",
  "student_type": "online",
  "device_id": "fcm-or-device-fingerprint",
  "device_name": "Samsung A54",
  "platform": "Android",
  "fcm_token": "fcm_token_value"
}
```

### Required Backend Behavior
- Validate all fields.
- If valid:
  - create account with `isEmailVerified = false` and `isActive = false` (or equivalent),
  - send verification code email,
  - return response that user is created but pending verification.
- If invalid:
  - return field-level errors in `errors`.

### Success Response Example (pending verification)
```json
{
  "success": true,
  "message": "تم إنشاء الحساب. يرجى تأكيد البريد الإلكتروني",
  "data": {
    "userId": "67f0c12ab9e8f22a33f0d111",
    "email": "ahmed.ali@example.com",
    "emailVerified": false,
    "accountActive": false,
    "verificationRequired": true
  }
}
```

### Validation Error Response Example
```json
{
  "success": false,
  "message": "خطأ في البيانات المدخلة",
  "data": null,
  "errors": {
    "username": "اسم المستخدم مستخدم بالفعل",
    "phone": "رقم الهاتف غير صالح",
    "nationalId": "الرقم القومي غير صحيح"
  }
}
```

---

## Step 2: Verify email and activate account

### Endpoint
`POST /auth/register/verify-code`

### Request Example
```json
{
  "email": "ahmed.ali@example.com",
  "code": "123456"
}
```

### Required Backend Behavior
- Validate code for that email.
- If code is correct:
  - set `isEmailVerified = true`,
  - set `isActive = true`,
  - mark account as fully active.
- If code is incorrect or expired:
  - return clear error in `errors.code`.

### Success Response Example (account activated)
```json
{
  "success": true,
  "message": "تم تأكيد البريد الإلكتروني وتفعيل الحساب بنجاح",
  "data": {
    "userId": "67f0c12ab9e8f22a33f0d111",
    "email": "ahmed.ali@example.com",
    "emailVerified": true,
    "accountActive": true
  }
}
```

### Verify Error Response Example
```json
{
  "success": false,
  "message": "رمز التحقق غير صحيح أو منتهي الصلاحية",
  "data": null,
  "errors": {
    "code": "رمز التحقق غير صحيح أو منتهي الصلاحية"
  }
}
```

---

## Optional Resend Code Endpoint

### Endpoint
`POST /auth/register/send-code`

### Request
```json
{
  "email": "ahmed.ali@example.com"
}
```

### Success Response
```json
{
  "success": true,
  "message": "تم إرسال رمز التحقق إلى البريد الإلكتروني",
  "data": {
    "sent": true
  }
}
```

---

## Error Contract (Must be consistent)

Backend should always return this structure on any error:

```json
{
  "success": false,
  "message": "خطأ في البيانات المدخلة",
  "data": null,
  "errors": {
    "field_name": "error message"
  }
}
```

Notes:
- Keep `message` generic.
- Put exact issue in `errors` with field keys.
- Return all available field errors together when possible.
