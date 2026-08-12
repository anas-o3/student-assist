# Student Assist Graduation Project

## Project
Software implementation of a secondary-school student assistant application
based on the approved Software Requirements Specification (SRS).

## Technologies
- Flutter
- Dart
- Firebase

## Primary References
Before implementing any feature, use these files as the primary references:

- docs/SRS.pdf
- docs/graduation_project_plan.docx

Do not introduce new product requirements that are not supported by these references
unless explicitly requested.

## Language and UI
- Arabic-first application.
- All user-facing screens must support RTL.
- Use Tajawal as the application font.
- Use Material 3.
- Do not change the approved visual identity without permission.

## Approved Colors
- Primary: #0F766E
- Primary Dark: #134E4A
- Primary Light: #F0FDFA
- Background: #F8FAFC
- Card: #FFFFFF
- Main Text: #0F172A
- Secondary Text: #64748B
- Error: #DC2626
- Success: #16A34A

Reuse the existing AppTheme instead of duplicating colors.

## Existing Flutter Structure

lib/
  app/
  models/
  repositories/
  screens/
    auth/
    student/
    admin/
  services/
  utils/
  widgets/
  main.dart

Preserve this structure unless there is a clear technical reason to change it.

## Functional Scope

Student:
- Account registration
- Login
- Logout
- Forgot password
- Grade selection
- Browse subjects
- Browse chapters and lessons
- Read lesson explanations
- Search
- Watch video resources
- View PDF summaries
- Open/download PDFs
- Answer quiz questions
- Evaluate answers
- Show correct answer and explanation
- Show quiz result
- Save results and student progress

Admin:
- Add educational content
- Edit educational content
- Delete educational content
- Manage questions and learning files

## Firebase
Firebase will be used for:
- Firebase Authentication
- Cloud Firestore
- Firebase Storage

Do not configure or integrate Firebase unless the current task explicitly asks for it.

## Coding Rules
- Implement only the requested feature.
- Do not implement future screens prematurely.
- Do not invent new requirements.
- Do not modify unrelated files.
- Keep code clean and maintainable.
- Avoid unnecessary dependencies.
- Prefer reusable widgets only when genuinely useful.
- Maintain separation between UI, services, repositories, and models.
- Clearly mark temporary mock data.

## Validation
After every implementation task:

1. Run dart format on modified Dart files.
2. Run flutter analyze.
3. Run flutter test.
4. Report:
   - files created
   - files modified
   - tests run
   - any assumptions made

## Git
- Codex may inspect git status and git diff.
- Do not run git commit unless explicitly requested.
- Do not run git push unless explicitly requested.
- Before committing, report all changed files and summarize the changes.
- Only commit after review and approval.