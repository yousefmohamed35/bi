# Course Rating & Review Contract (Mobile <-> Backend)

This document defines the expected flow for course ratings and reviews:

1. Student submits a rating/review for a course.
2. Backend stores it with moderation status.
3. If moderation is enabled, review is hidden until admin approval.
4. Mobile fetches only visible/approved reviews for public display.

---

## 1) Submit Course Review

### Endpoint
`POST /courses/{courseId}/reviews`

### Request Example
```json
{
  "rating": 5,
  "title": "Excellent course",
  "comment": "Very clear explanation and practical examples."
}
```

### Required Backend Behavior
- Validate:
  - `rating` is integer from 1 to 5.
  - `title` is not empty.
  - `comment` is not empty.
- Ensure reviewer is authenticated and authorized (usually enrolled/completed course policy as defined by backend).
- Prevent duplicate abuse if needed (e.g. one active review per user/course).
- Save moderation status:
  - `approved` (immediately visible), or
  - `pending` (requires admin approval before visibility), or
  - `rejected`.

### Success Response Example (Moderation Enabled)
```json
{
  "success": true,
  "message": "Review submitted successfully and pending admin approval",
  "data": {
    "id": "review_123",
    "courseId": "course_987",
    "userId": "user_111",
    "rating": 5,
    "title": "Excellent course",
    "comment": "Very clear explanation and practical examples.",
    "status": "pending",
    "createdAt": "2026-04-20T10:00:00.000Z"
  }
}
```

### Success Response Example (No Moderation)
```json
{
  "success": true,
  "message": "Review submitted successfully",
  "data": {
    "id": "review_124",
    "courseId": "course_987",
    "userId": "user_111",
    "rating": 5,
    "title": "Excellent course",
    "comment": "Very clear explanation and practical examples.",
    "status": "approved",
    "createdAt": "2026-04-20T10:00:00.000Z"
  }
}
```

---

## 2) Get Course Reviews (Public Display)

### Endpoint
`GET /courses/{courseId}/reviews?page=1&per_page=20&rating=5`

### Required Backend Behavior
- Return paginated review list.
- Public/mobile listing should include only visible reviews (normally `approved` only).
- Support optional rating filter.
- Include aggregate summary if available (average rating, count).

### Success Response Example
```json
{
  "success": true,
  "message": "Reviews fetched successfully",
  "data": {
    "courseId": "course_987",
    "summary": {
      "averageRating": 4.7,
      "totalReviews": 120
    },
    "reviews": [
      {
        "id": "review_200",
        "rating": 5,
        "title": "Very useful",
        "comment": "I liked the structure and pacing.",
        "user": {
          "id": "user_77",
          "name": "Ahmed Ali"
        },
        "status": "approved",
        "createdAt": "2026-04-19T12:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "perPage": 20,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

---

## 3) Admin Moderation (If Enabled)

### Purpose
Approve or reject pending reviews before showing them publicly.

### Suggested Admin Endpoint (example)
`PATCH /admin/reviews/{reviewId}/status`

### Request Example
```json
{
  "status": "approved"
}
```

### Response Example
```json
{
  "success": true,
  "message": "Review status updated",
  "data": {
    "id": "review_123",
    "status": "approved",
    "moderatedBy": "admin_1",
    "moderatedAt": "2026-04-20T10:10:00.000Z"
  }
}
```

---

## 4) Error Contract (Must be consistent)

Backend should always return this structure on validation/business errors:

```json
{
  "success": false,
  "message": "Validation failed",
  "data": null,
  "errors": {
    "rating": "Rating must be between 1 and 5"
  }
}
```

Common cases:
- `401`: user not authenticated.
- `403`: user not allowed to review this course.
- `404`: course not found.
- `409`: duplicate review conflict (if one review/user/course policy exists).

---

## Mobile Mapping (Current App)

Current Flutter integration already uses:

- Submit review: `POST /courses/{courseId}/reviews`
- Load reviews: `GET /courses/{courseId}/reviews`

From code:
- `lib/services/courses_service.dart`
- `lib/core/api/api_endpoints.dart`
- `lib/screens/secondary/course_details_screen.dart`
