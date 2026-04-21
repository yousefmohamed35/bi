# Lessons UI Contract (Mobile <-> Backend)

This document defines the response shape needed by the mobile Lessons UI in course details and lesson viewer screens.

It is based on the current app behavior and accepted fallback keys.

---

## 1) Endpoints used by lessons UI

### Course details (source of curriculum/lessons list)
`GET /courses/:courseId`

### Lesson content (source of lesson materials/video details)
`GET /courses/:courseId/lessons/:lessonId/content`

### Optional lesson details
`GET /courses/:courseId/lessons/:lessonId`

### Update progress
`POST /courses/:courseId/lessons/:lessonId/progress`

Request body:
```json
{
  "watched_seconds": 120,
  "is_completed": false
}
```

---

## 2) Standard response envelope (required)

Backend responses should be consistent for all lesson-related endpoints:

```json
{
  "success": true,
  "message": "ok",
  "data": {}
}
```

Error format:
```json
{
  "success": false,
  "message": "Validation error",
  "data": null,
  "errors": {
    "field_name": "reason"
  }
}
```

---

## 3) `GET /courses/:courseId` required data shape

### Top-level course fields used by UI
- `id` (string|number)
- `title` (string)
- `duration_hours` (number|string) or `durationHours`
- `lessons_count` (number) or `lessonsCount`
- `instructor.name` (string) or fallback `instructor_name` / `instructorName`

### Lessons sources (backend can provide either)
1. `curriculum` (preferred by mobile)
2. `lessons` (fallback if `curriculum` is empty)

### Curriculum item behavior
A curriculum item is treated as a **topic/section** if:
- it has a `lessons` array (even empty), OR
- it does not contain video indicators (`video`, `youtube_id`, `youtubeVideoId`).

Otherwise it is treated as a **standalone lesson**.

Topic fields expected:
- `id`
- `title`
- `order`
- `type` (optional)
- `lessons` (array)

Lesson fields expected inside `curriculum[].lessons[]` or `lessons[]`:
- `id` (required)
- `title` (required for display)
- `type` (recommended: `video`, `pdf`, `exam`, `image`, `record`)
- `order` (optional)
- `duration` or `duration_minutes` (optional, shown in UI when present)
- `description` (optional)
- `is_locked` (optional)
- `is_completed` (optional)
- `course_id` or `courseId` (recommended for deep linking/viewer fallback)

---

## 4) Lesson type mapping used by mobile

The app normalizes lesson type as follows:

- `video` if `type` contains `video`, or has `video` object / `youtube_id`
- `pdf` if `type` contains `pdf`/`file`/`material`, or has one of:
  - `content_pdf`
  - `pdf`
  - `file_url`
- `exam` if `type` contains `exam`/`quiz`/`test`, or has `exam_id`
- `image` if `type` contains `image`/`photo`/`gallery`, or has:
  - `image`
  - `image_url`
- `record` if `type` contains `record`/`audio`/`sound`, or has:
  - `audio_url`
  - `record_url`
  - `sound_url`

If ambiguous, mobile defaults to `video`.

---

## 5) Video contract for lesson playback

Mobile resolves video source in this order:

1. `lesson.video_url`
2. `lessonContent.video.url` (from lesson content endpoint)
3. `lesson.video.url`
4. YouTube ID fallback:
   - `lessonContent.video.youtube_id`
   - `lesson.video.youtube_id`
   - `lesson.youtube_id`
   - `lesson.youtubeVideoId`
5. Backend stream ID fallback:
   - `lessonContent.video.id` or `video_id` or `videoId`
   - `lesson.video.id` or `video_id` or `videoId`
   - `lesson.video_id` or `lesson.videoId`

When backend video ID is available, app can build:
`/videos/:videoId/stream?quality=auto|1080p|720p|480p|360p`

### Video object shape (recommended)
```json
{
  "video": {
    "id": "vid_123",
    "url": "https://your-domain/api/videos/vid_123/stream?quality=auto",
    "youtube_id": "",
    "qualities": {
      "auto": "https://your-domain/api/videos/vid_123/stream?quality=auto",
      "1080p": "https://your-domain/api/videos/vid_123/stream?quality=1080p",
      "720p": "https://your-domain/api/videos/vid_123/stream?quality=720p"
    }
  }
}
```

`qualities` may also come under alternate keys (`quality`, `sources`, `resolutions`, `streams`).

---

## 6) `GET /courses/:courseId/lessons/:lessonId/content` expected shape

At minimum, backend should return:

```json
{
  "id": "lesson_1",
  "title": "Intro",
  "type": "video",
  "video": {
    "id": "vid_123",
    "url": "https://your-domain/api/videos/vid_123/stream?quality=auto",
    "youtube_id": null
  },
  "content_pdf": null,
  "attachments": []
}
```

### Content-level fields used by UI/materials
- `video` object (as above) for viewer quality/source resolution
- `content_pdf` for PDF materials panel
- `attachments[]` fallback list; first item with `url` is used when direct field missing

---

## 7) Asset URL rules

For non-video resources (pdf/image/record), backend may return:
- full URL (`https://...`) OR
- relative URL (`/uploads/...` or `uploads/...`)

Mobile normalizes relative paths by prefixing API image base URL.

---

## 8) Recommended full example for `GET /courses/:courseId`

```json
{
  "success": true,
  "message": "ok",
  "data": {
    "id": "course_55",
    "title": "Biology 101",
    "duration_hours": 24,
    "lessons_count": 6,
    "instructor": {
      "id": "inst_1",
      "name": "Dr. Ahmed"
    },
    "curriculum": [
      {
        "id": "topic_1",
        "title": "Chapter 1",
        "order": 1,
        "type": "section",
        "lessons": [
          {
            "id": "lesson_1",
            "course_id": "course_55",
            "title": "Lesson Video",
            "type": "video",
            "order": 1,
            "duration_minutes": 12,
            "is_locked": false,
            "is_completed": false,
            "video": {
              "id": "vid_123",
              "url": "https://your-domain/api/videos/vid_123/stream?quality=auto",
              "qualities": {
                "auto": "https://your-domain/api/videos/vid_123/stream?quality=auto",
                "720p": "https://your-domain/api/videos/vid_123/stream?quality=720p"
              }
            }
          },
          {
            "id": "lesson_2",
            "course_id": "course_55",
            "title": "Lesson PDF",
            "type": "pdf",
            "content_pdf": "/uploads/materials/ch1.pdf"
          },
          {
            "id": "lesson_3",
            "course_id": "course_55",
            "title": "Lesson Record",
            "type": "record",
            "audio_url": "/uploads/audio/ch1_intro.mp3"
          },
          {
            "id": "lesson_4",
            "course_id": "course_55",
            "title": "Lesson Image",
            "type": "image",
            "image_url": "/uploads/images/ch1_map.png"
          },
          {
            "id": "lesson_5",
            "course_id": "course_55",
            "title": "Trial Exam",
            "type": "exam",
            "exam_id": "exam_77"
          }
        ]
      }
    ]
  }
}
```

---

## 9) Backend implementation checklist

- Return `curriculum` with topics + nested `lessons` when possible.
- Ensure every lesson has stable `id` and `title`.
- Provide `type` explicitly to avoid wrong grouping in UI.
- For videos, provide either:
  - direct `video_url`, or
  - `video.url`, or
  - `youtube_id`, or
  - `video_id` (so mobile can build stream URL).
- For PDF/image/record lessons, provide one valid URL field as listed above.
- Keep response envelope consistent (`success`, `message`, `data`, optional `errors`).

