# Project-specific ProGuard rules for the release build.
# Flutter and its plugins ship their own rules; the app talks to native code
# through dart:ffi (sqflite_common_ffi), which reflection-based
# shrinking never sees, so no keeps are required today. If a future plugin
# uses Java reflection, add its -keep rules here.
