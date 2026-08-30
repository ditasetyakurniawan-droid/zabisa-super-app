export const permissions = {
  backoffice: 'backoffice.access',
  usersRead: 'users.read',
  usersWrite: 'users.write',
  rolesWrite: 'roles.write',
  auditRead: 'audit.read',
  contentRead: 'content.read',
  contentWrite: 'content.write',
  kajianRead: 'kajian.read',
  kajianWrite: 'kajian.write',
  donationRead: 'donation.read',
  donationWrite: 'donation.write',
  donationVerify: 'donation.verify',
  studentsRead: 'students.read',
  studentsWrite: 'students.write',
  guardiansRead: 'guardians.read',
  guardiansWrite: 'guardians.write',
  tahfidzRead: 'tahfidz.read',
  tahfidzWrite: 'tahfidz.write',
  academicsRead: 'academics.read',
  academicsWrite: 'academics.write',
  academicsPublish: 'academics.publish',
  attendanceRead: 'attendance.read',
  attendanceWrite: 'attendance.write',
  notificationsRead: 'notifications.read',
  notificationsWrite: 'notifications.write',
} as const;

export type Permission = typeof permissions[keyof typeof permissions];
export type InternalRole = 'SUPER_ADMIN'|'ADMIN'|'OPERATOR'|'CONTENT_EDITOR'|'FINANCE'|'USTADZ'|'GURU_AGAMA'|'GURU_AKADEMIK'|'WALI_KELAS';

const rolePermissions: Record<InternalRole, readonly Permission[]> = {
  SUPER_ADMIN: Object.values(permissions),
  ADMIN: [permissions.backoffice,permissions.usersRead,permissions.usersWrite,permissions.auditRead,permissions.contentRead,permissions.contentWrite,permissions.kajianRead,permissions.kajianWrite,permissions.donationRead,permissions.donationWrite,permissions.donationVerify,permissions.studentsRead,permissions.studentsWrite,permissions.guardiansRead,permissions.guardiansWrite,permissions.tahfidzRead,permissions.tahfidzWrite,permissions.academicsRead,permissions.academicsWrite,permissions.academicsPublish,permissions.attendanceRead,permissions.attendanceWrite,permissions.notificationsRead,permissions.notificationsWrite],
  OPERATOR: [permissions.backoffice,permissions.studentsRead,permissions.studentsWrite,permissions.guardiansRead,permissions.guardiansWrite,permissions.attendanceRead,permissions.attendanceWrite,permissions.notificationsRead,permissions.notificationsWrite],
  CONTENT_EDITOR: [permissions.backoffice,permissions.contentRead,permissions.contentWrite,permissions.kajianRead,permissions.kajianWrite,permissions.notificationsRead,permissions.notificationsWrite],
  FINANCE: [permissions.backoffice,permissions.donationRead,permissions.donationWrite,permissions.donationVerify],
  USTADZ: [permissions.backoffice,permissions.studentsRead,permissions.tahfidzRead,permissions.tahfidzWrite],
  GURU_AGAMA: [permissions.backoffice,permissions.studentsRead,permissions.academicsRead,permissions.academicsWrite,permissions.academicsPublish],
  GURU_AKADEMIK: [permissions.backoffice,permissions.studentsRead,permissions.academicsRead,permissions.academicsWrite,permissions.academicsPublish],
  WALI_KELAS: [permissions.backoffice,permissions.studentsRead,permissions.academicsRead,permissions.attendanceRead,permissions.attendanceWrite],
};

export const roleLabels: Record<string,string> = {
  SUPER_ADMIN:'Super Administrator', ADMIN:'Administrator', OPERATOR:'Operator', CONTENT_EDITOR:'Content Editor', FINANCE:'Bagian Keuangan', USTADZ:'Ustadz / Musyrif', GURU_AGAMA:'Guru Agama', GURU_AKADEMIK:'Guru Akademik', WALI_KELAS:'Wali Kelas', GUARDIAN:'Wali Santri', WALI_SANTRI:'Wali Santri', DONOR:'Donatur', REGISTERED_PUBLIC:'Pengguna Terdaftar',
};

export function normalizeRole(role:string){return role==='TEACHER'?'GURU_AKADEMIK':role.toUpperCase()}
export function isInternalRole(role:string): role is InternalRole {return Object.prototype.hasOwnProperty.call(rolePermissions,normalizeRole(role))}
export function can(role:string, permission:Permission){const normalized=normalizeRole(role);return isInternalRole(normalized)&&rolePermissions[normalized].includes(permission)}

export const routePermission: Record<string,Permission> = {
  '/dashboard': permissions.backoffice,
  '/content': permissions.contentRead,
  '/kajian': permissions.kajianRead,
  '/donation': permissions.donationRead,
  '/students': permissions.studentsRead,
  '/guardians': permissions.guardiansRead,
  '/tahfidz': permissions.tahfidzRead,
  '/academics': permissions.academicsRead,
  '/attendance': permissions.attendanceRead,
  '/notifications': permissions.notificationsRead,
  '/access': permissions.usersRead,
  '/audit': permissions.auditRead,
};

export function canAccessPath(role:string,path:string){const entry=Object.entries(routePermission).find(([prefix])=>path===prefix||path.startsWith(prefix+'/'));return entry?can(role,entry[1]):can(role,permissions.backoffice)}
export function permissionsFor(role:string){const normalized=normalizeRole(role);return isInternalRole(normalized)?rolePermissions[normalized]:[]}
