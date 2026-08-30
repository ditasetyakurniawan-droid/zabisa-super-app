package authz

import "testing"

func TestCriticalRoleBoundaries(t *testing.T) {
	tests := []struct {
		role       string
		permission Permission
		want       bool
	}{
		{"SUPER_ADMIN", RolesWrite, true},
		{"ADMIN", RolesWrite, false},
		{"CONTENT_EDITOR", ContentWrite, true},
		{"CONTENT_EDITOR", DonationVerify, false},
		{"FINANCE", DonationVerify, true},
		{"OPERATOR", AttendanceWrite, true},
		{"OPERATOR", AcademicsWrite, false},
		{"USTADZ", TahfidzWrite, true},
		{"GURU_AKADEMIK", AcademicsWrite, true},
		{"WALI_KELAS", AcademicsWrite, false},
		{"GUARDIAN", BackofficeAccess, false},
		{"TEACHER", AcademicsWrite, true},
	}
	for _, tt := range tests {
		if got := Has(tt.role, tt.permission); got != tt.want {
			t.Fatalf("Has(%q,%q)=%v want %v", tt.role, tt.permission, got, tt.want)
		}
	}
}
