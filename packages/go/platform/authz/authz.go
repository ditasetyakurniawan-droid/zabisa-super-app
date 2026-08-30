package authz

import "strings"

type Permission string

const (
	BackofficeAccess   Permission = "backoffice.access"
	UsersRead          Permission = "users.read"
	UsersWrite         Permission = "users.write"
	RolesWrite         Permission = "roles.write"
	AuditRead          Permission = "audit.read"
	ContentRead        Permission = "content.read"
	ContentWrite       Permission = "content.write"
	KajianRead         Permission = "kajian.read"
	KajianWrite        Permission = "kajian.write"
	DonationRead       Permission = "donation.read"
	DonationWrite      Permission = "donation.write"
	DonationVerify     Permission = "donation.verify"
	StudentsRead       Permission = "students.read"
	StudentsWrite      Permission = "students.write"
	GuardiansRead      Permission = "guardians.read"
	GuardiansWrite     Permission = "guardians.write"
	TahfidzRead        Permission = "tahfidz.read"
	TahfidzWrite       Permission = "tahfidz.write"
	AcademicsRead      Permission = "academics.read"
	AcademicsWrite     Permission = "academics.write"
	AcademicsPublish   Permission = "academics.publish"
	AttendanceRead     Permission = "attendance.read"
	AttendanceWrite    Permission = "attendance.write"
	NotificationsRead  Permission = "notifications.read"
	NotificationsWrite Permission = "notifications.write"
)

var allPermissions = []Permission{
	BackofficeAccess, UsersRead, UsersWrite, RolesWrite, AuditRead,
	ContentRead, ContentWrite, KajianRead, KajianWrite,
	DonationRead, DonationWrite, DonationVerify,
	StudentsRead, StudentsWrite, GuardiansRead, GuardiansWrite,
	TahfidzRead, TahfidzWrite,
	AcademicsRead, AcademicsWrite, AcademicsPublish,
	AttendanceRead, AttendanceWrite,
	NotificationsRead, NotificationsWrite,
}

var rolePermissions = map[string]map[Permission]struct{}{
	"SUPER_ADMIN": permissionSet(allPermissions...),
	"ADMIN": permissionSet(
		BackofficeAccess, UsersRead, UsersWrite, AuditRead,
		ContentRead, ContentWrite, KajianRead, KajianWrite,
		DonationRead, DonationWrite, DonationVerify,
		StudentsRead, StudentsWrite, GuardiansRead, GuardiansWrite,
		TahfidzRead, TahfidzWrite,
		AcademicsRead, AcademicsWrite, AcademicsPublish,
		AttendanceRead, AttendanceWrite,
		NotificationsRead, NotificationsWrite,
	),
	"OPERATOR": permissionSet(
		BackofficeAccess,
		StudentsRead, StudentsWrite, GuardiansRead, GuardiansWrite,
		AttendanceRead, AttendanceWrite,
		NotificationsRead, NotificationsWrite,
	),
	"CONTENT_EDITOR": permissionSet(
		BackofficeAccess,
		ContentRead, ContentWrite, KajianRead, KajianWrite,
		NotificationsRead, NotificationsWrite,
	),
	"FINANCE": permissionSet(
		BackofficeAccess,
		DonationRead, DonationWrite, DonationVerify,
	),
	"USTADZ": permissionSet(
		BackofficeAccess,
		StudentsRead,
		TahfidzRead, TahfidzWrite,
	),
	"GURU_AGAMA": permissionSet(
		BackofficeAccess,
		StudentsRead,
		AcademicsRead, AcademicsWrite, AcademicsPublish,
	),
	"GURU_AKADEMIK": permissionSet(
		BackofficeAccess,
		StudentsRead,
		AcademicsRead, AcademicsWrite, AcademicsPublish,
	),
	"WALI_KELAS": permissionSet(
		BackofficeAccess,
		StudentsRead,
		AcademicsRead,
		AttendanceRead, AttendanceWrite,
	),
}

func permissionSet(values ...Permission) map[Permission]struct{} {
	m := make(map[Permission]struct{}, len(values))
	for _, value := range values {
		m[value] = struct{}{}
	}
	return m
}

func NormalizeRole(role string) string {
	r := strings.ToUpper(strings.TrimSpace(role))
	// Backward-compatible alias used by an earlier local development seed.
	if r == "TEACHER" {
		return "GURU_AKADEMIK"
	}
	return r
}

func Has(role string, permission Permission) bool {
	permissions, ok := rolePermissions[NormalizeRole(role)]
	if !ok {
		return false
	}
	_, ok = permissions[permission]
	return ok
}

func IsInternal(role string) bool   { return Has(role, BackofficeAccess) }
func IsSuperAdmin(role string) bool { return NormalizeRole(role) == "SUPER_ADMIN" }

func Permissions(role string) []Permission {
	set := rolePermissions[NormalizeRole(role)]
	out := make([]Permission, 0, len(set))
	for _, permission := range allPermissions {
		if _, ok := set[permission]; ok {
			out = append(out, permission)
		}
	}
	return out
}
