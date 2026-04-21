# Course Progress Tracking Contract (Mobile <-> Backend)

This document defines the backend updates required to support reliable course progress tracking in mobile for all lesson types (video, record/audio, pdf, image, exam).

---

## 1) Track Lesson Progress

### Endpoint
`POST /courses/{courseId}/lessons/{lessonId}/track-progress`

### Request Body
```json
{
  "content_type": "video",
  "is_completed": true,
  "watched_seconds": 520,
  "completion_ratio": 0.97
}
```

### Request Fields
- `content_type` (required): one of
  - `video`
  - `record`
  - `pdf`
  - `image`
  - `exam`
- `is_completed` (required): boolean
- `watched_seconds` (optional): integer, used for `video`/`record`
- `completion_ratio` (optional): number between `0` and `1`, used for `video`/`record`

### Required Backend Behavior
- Validate authenticated student.
- Validate student is enrolled in `{courseId}`.
- Validate lesson belongs to `{courseId}`.
- Validate payload by `content_type`:
  - For `video`/`record`: accept and store `watched_seconds` and/or `completion_ratio`.
  - For `pdf`/`image`/`exam`: allow completion tracking without watch fields.
- Upsert lesson progress (idempotent): multiple completion calls should not duplicate counters.
- Recalculate and store enrollment/course progress after every update.
- Return updated lesson and enrollment progress data in response.

### Success Response Example
```json
{
  "success": true,
  "message": "Lesson progress tracked successfully",
  "data": {
    "course_id": "12",
    "lesson_id": "77",
    "content_type": "video",
    "is_completed": true,
    "watched_seconds": 520,
    "completion_ratio": 0.97,
    "completed_lessons": 8,
    "total_lessons": 20,
    "course_progress": 40
  }
}
```

---

## 2) Progress Calculation Rules

Backend should compute progress from completed lessons, not from video only.

### Suggested Formula
- `completed_lessons = count(lesson where is_completed = true)`
- `course_progress = round((completed_lessons / total_lessons) * 100)`

### Lesson Completion Definition
- `video`/`record`: completed when backend receives `is_completed = true`
  - (mobile currently sends completion when playback reaches around 95%)
- `pdf`: completed when student opens and exits lesson viewer
- `image`: completed when student opens and exits image viewer
- `exam`: completed when exam is submitted successfully

---

## 3) Enrollment List Contract (My Courses Screen)

### Endpoint
`GET /enrollments?status=all&page=1&per_page=20`

### Required Fields Per Enrollment
- `progress` (0..100)
- `completed_lessons`
- `total_lessons`
- `course` object with course metadata

### Response Example
```json
{
  "success": true,
  "message": "Enrollments fetched successfully",
  "data": [
    {
      "id": "enroll_1",
      "course_id": "12",
      "progress": 40,
      "completed_lessons": 8,
      "total_lessons": 20,
      "enrolled_at": "2026-04-20T10:00:00.000Z",
      "course": {
        "id": "12",
        "title": "Clinical Basics",
        "thumbnail": "/uploads/courses/12.jpg"
      }
    }
  ]
}
```

---

## 4) Course Details Contract (Lessons Completion State)

### Endpoint
`GET /courses/{courseId}`

### Required Behavior
- Each lesson in `curriculum` / `lessons` should include completion state for current student:
  - `is_completed` boolean
- Optional compatibility alias:
  - `completed` boolean

This is needed so mobile can render green/check state immediately in lesson list.

---

## 5) Error Contract (Consistent)

```json
{
  "success": false,
  "message": "Validation failed",
  "data": null,
  "errors": {
    "content_type": "Invalid content_type value"
  }
}
```

### Common Status Codes
- `400` invalid payload
- `401` unauthenticated
- `403` not enrolled / not allowed
- `404` course or lesson not found
- `409` conflict (if business rule conflict exists)

---

## 6) Backward Compatibility

Mobile still has legacy fallback for old endpoint:
- `POST /courses/{courseId}/lessons/{lessonId}/progress`

But full multi-type tracking (`pdf`, `image`, `exam`, `record`) requires the new endpoint:
- `POST /courses/{courseId}/lessons/{lessonId}/track-progress`

---

## 7) Backend Acceptance Checklist

- [ ] New endpoint implemented and authenticated.
- [ ] Supports all `content_type` values listed above.
- [ ] Endpoint is idempotent for repeated completion events.
- [ ] Recalculates and persists enrollment progress correctly.
- [ ] `GET /enrollments` returns updated `progress`, `completed_lessons`, `total_lessons`.
- [ ] `GET /courses/{courseId}` returns `is_completed` at lesson level for current student.
- [ ] Error format is consistent with existing API contract.

---

## Mobile Integration Reference

Current app integration points:
- `lib/core/api/api_endpoints.dart`
- `lib/services/courses_service.dart`
- `lib/screens/secondary/course_details_screen.dart`
- `lib/screens/secondary/enrolled_screen.dart`
