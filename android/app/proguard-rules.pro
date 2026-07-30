# WorkManager + Room: R8 strips the generated _Impl classes needed at runtime.
-keep class * extends androidx.room.RoomDatabase {
    *;
}
-keep class * extends androidx.work.impl.WorkDatabase_Impl { *; }
