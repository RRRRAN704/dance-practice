# Dance Practice App

## Project Goal
An iOS dance practice app designed for learning choreography from videos.

## Tech Stack
- iOS: Swift / SwiftUI
- Backend: Java 11 + Spring Boot
- Database: PostgreSQL
- Cloud: AWS EC2 + S3

## Core Player Features
- Video playback
- Playback speed: 0.25x–2.0x
- Mirror video
- A-B loop
- Thumbnail timeline
- Metronome
- Fullscreen mode

## Architecture
Keep UI, business logic, and video playback logic separated.

## Development Rules
- Prefer small reusable SwiftUI components.
- Do not introduce new libraries unless necessary.
- Explain major architectural decisions before making them.
- Do not rewrite unrelated files.
- Keep commits/features small.
- Build and check for compile errors after major changes.