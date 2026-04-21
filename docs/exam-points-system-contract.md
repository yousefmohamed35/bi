# Exam Points System Contract

This document defines the backend contract for:
- Admin-configurable point ranges per exam.
- Awarding points after exam submission.
- Student endpoint for exam history with earned points and total points.

## 1) Admin creates/updates exam point rules

Attach point ranges to each exam while creating or editing it.

### Request payload (inside exam create/update)

```json
{
  "title": "Physics Midterm",
  "course_id": 123,
  "passing_score": 60,
  "point_system_enabled": true,
  "point_rules": [
    { "min_percent": 100, "max_percent": 100, "points": 5 },
    { "min_percent": 90, "max_percent": 99.99, "points": 4 },
    { "min_percent": 80, "max_percent": 89.99, "points": 3 },
    { "min_percent": 70, "max_percent": 79.99, "points": 2 },
    { "min_percent": 0, "max_percent": 69.99, "points": 0 }
  ]
}
```

### Validation rules

- `point_system_enabled` controls whether points are awarded for this exam.
- `point_rules` required when `point_system_enabled=true`.
- Each rule requires:
  - `min_percent` number between `0` and `100`.
  - `max_percent` number between `0` and `100`.
  - `points` integer `>= 0`.
- `min_percent <= max_percent`.
- Rules must not overlap.
- Recommended: full coverage of `0..100` to avoid undefined ranges.

## 2) Awarding points on exam submission

When student submits an exam:

1. Compute score percentage.
2. If `point_system_enabled=true`, match the score against the exam rules.
3. Award matched points.
4. Save an immutable points transaction for audit and deduping.

### Required transaction fields

- `student_id`
- `exam_id`
- `exam_attempt_id`
- `score_percent`
- `points_awarded`
- `rule_snapshot` (or `rule_id` + version)
- `awarded_at`

### Idempotency

Backend must prevent duplicate awards for the same `exam_attempt_id`.

## 3) Student endpoint: exam history with points

## GET `/api/my-exam-results`

Return exam history entries with points earned per exam and total points.

### Response

```json
{
  "success": true,
  "data": {
    "total_points": 17,
    "history": [
      {
        "exam_id": 31,
        "title": "Physics Midterm",
        "score": 100,
        "correct_answers": 20,
        "total_questions": 20,
        "passed": true,
        "earned_points": 5,
        "completed_at": "2026-04-17T08:23:00Z"
      },
      {
        "exam_id": 42,
        "title": "Chemistry Quiz",
        "score": 88,
        "correct_answers": 22,
        "total_questions": 25,
        "passed": true,
        "earned_points": 3,
        "completed_at": "2026-04-10T11:00:00Z"
      }
    ]
  }
}
```

### Notes

- `earned_points` is points gained from this exam result.
- `total_points` is cumulative points for the logged-in student.
- `history` should be ordered by `completed_at desc`.

## 4) Compatibility guidance for current mobile app

Current app now supports:
- `data.history` or fallback lists (`completed`, `items`).
- `total_points` in root or inside `summary`.
- per-exam points in `earned_points`, `points_awarded`, or `points`.

To keep behavior predictable, prefer returning:
- `data.total_points`
- `data.history[].earned_points`
