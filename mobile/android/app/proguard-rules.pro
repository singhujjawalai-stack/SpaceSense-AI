# SpaceSense AI proguard rules.
# The Flutter engine AAR ships its own consumer rules, so only app-specific
# adjustments belong here. Keep this minimal — overly aggressive rules can
# break plugins that use reflection.

# flutter_secure_storage / supabase: keep default behavior (no reflection issues known)

# Keep annotations used by R8 for Kotlin nullability checks
-keepattributes *Annotation*, InnerClasses, Signature
