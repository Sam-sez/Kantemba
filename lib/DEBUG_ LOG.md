DEBUG_LOG
Attempt 1 (2026-09-29)
Symptom: Scanner screen shows an error/arrow screen; camera never opens although permission is Allowed in Android Settings.
Evidence: Android Settings shows Camera = Allowed (so manifest has CAMERA). No error code captured yet. Code comments mention an earlier "genericError / getClass() on a null object reference" crash.
Hypothesis: (1) mobile_scanner ^5 native error at camera start, (2) plugin/Flutter/Gradle version mismatch, (3) device lacks needed services.
Change made: diag: in-app AppLog + log viewer, scanner logging, CI prints versions/permissions.
Result: pending
Conclusion / next step: reproduce, tap "View / copy logs", paste here.