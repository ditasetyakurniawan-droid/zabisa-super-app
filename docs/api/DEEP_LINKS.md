# Zabisa Deep-Link Contract

Deep links are navigation hints, not authorization credentials.

Supported canonical links:

```text
zabisa://kajian/{kajian_id}
zabisa://guardian/students/{student_id}/tahfidz/{entry_id}
zabisa://guardian/students/{student_id}/academic/{grade_id}
```

Legacy compatibility:

```text
zabisa://tahfidz/{entry_id}
zabisa://academic/{grade_id}
```

Private links are resolved only after authentication and the backend continues to enforce Guardian-to-student object authorization.
