# Notifications Behavior Contract

This document defines how notifications should work in the app:

- In-app notifications list (`/notifications`)
- System push notifications received outside the app (background/terminated)
- Navigation to a specific page when user taps a notification

## Current Expected Behavior

- When a push notification arrives while app is open, a local notification is shown.
- When user taps a notification (from system tray or in-app list), the app should open the target page.
- If payload is missing or invalid, app falls back to `/notifications`.

## Supported Target Routes

Only these routes are accepted directly from notification payload:

- `/notifications`
- `/home`
- `/courses`
- `/progress`
- `/dashboard`
- `/live-courses`
- `/downloads`
- `/certificates`
- `/exams`
- `/my-exams`
- `/chat`
- `/settings`
- `/enrolled`

Any other route value is ignored for safety and fallback is used.

## Payload Contract (Server -> App)

The app can resolve navigation from these payload keys (priority order):

1. `route` or `target_route`
2. `screen` or `target_screen`
3. `action_value` (if it is a valid route)
4. `action_type` (mapped to route)

### Recommended payload example (best)

```json
{
  "title": "New live class",
  "body": "Your class starts in 10 minutes",
  "data": {
    "route": "/live-courses"
  }
}
```

### Alternative payload example (action_type mapping)

```json
{
  "title": "New certificate available",
  "body": "Tap to open your certificates",
  "data": {
    "action_type": "certificates"
  }
}
```

## `action_type` Mapping

If route is not provided, app maps these values:

- `notifications`, `notification` -> `/notifications`
- `home` -> `/home`
- `courses`, `course` -> `/courses`
- `live_courses`, `live` -> `/live-courses`
- `downloads` -> `/downloads`
- `certificates`, `certificate` -> `/certificates`
- `progress` -> `/progress`
- `dashboard` -> `/dashboard`
- `chat`, `messages` -> `/chat`
- `exams` -> `/exams`
- `my_exams` -> `/my-exams`

## In-App Notification List Contract

API response items in `/notifications` endpoint should include at least:

- `id` (string/int)
- `title`
- `body` or `message`
- One of navigation keys: `route`, `target_route`, `action_type`, `action_value`

When user taps an item in notifications list:

1. App marks notification as read.
2. App resolves target route from the same contract above.
3. App navigates to target route.
4. If cannot resolve target, app opens `/notifications`.

## Out-of-App Tap Flow

For notifications received in background/terminated:

1. Push arrives via FCM.
2. App stores payload in local notification payload.
3. User taps notification.
4. App reads payload data and resolves route.
5. App opens route (or `/notifications` fallback).

## Backend Requirements

- Always send `data.route` for deterministic behavior.
- Keep route value in supported list above.
- Keep `action_type` only as fallback compatibility.
- For future detail pages (course/lesson/chat thread), provide a separate deep-link contract with IDs and app-side fetch logic.
