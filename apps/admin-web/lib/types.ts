export type RowRecord = Record<string, unknown>;

export type AdminUser = RowRecord & {
  id: string;
  display_name: string;
  email: string;
  phone?: string | null;
  role: string;
  status: string;
};

export type Student = RowRecord & {
  id: string;
  student_no: string;
  full_name: string;
  photo_url?: string | null;
  class_name?: string | null;
  program_name?: string | null;
  academic_year?: string | null;
  status: string;
};

export type GuardianLink = RowRecord & {
  id: string;
  student_id?: string;
  student_name?: string;
  guardian_user_id: string;
  relationship: string;
  status: string;
};

export type AttendanceRow = RowRecord & {
  id?: string;
  student_id?: string;
  student_name?: string;
  date: string;
  status: string;
  note?: string | null;
};

export type DonationCampaign = RowRecord & {
  id: string;
  name: string;
  slug: string;
  description?: string;
  category?: string;
  collected_amount?: number | string | null;
  target_amount?: number | string | null;
  cover_url?: string | null;
  deadline?: string | null;
  status: string;
};

export type DonationTransaction = RowRecord & {
  id: string;
  created_at?: string;
  campaign_name?: string;
  donor_name?: string;
  anonymous?: boolean;
  amount?: number | string;
  payment_method?: string;
  status: string;
};

export type PaymentMethod = RowRecord & {
  id: string;
  method_code: string;
  display_name: string;
  bank_name?: string;
  account_number?: string;
  account_holder?: string;
  instructions?: string;
  active: boolean;
};

export type AdminNotification = RowRecord & {
  id: string;
  created_at?: string;
  type: string;
  title: string;
  message: string;
  user_id?: string | null;
};

export type ScheduledNotification = RowRecord & {
  id: string;
  scheduled_at?: string;
  title: string;
  type: string;
  processed_at?: string | null;
};

export type TahfidzEntry = RowRecord & {
  id: string;
  date?: string;
  activity_date?: string;
  student_id: string;
  surah: string;
  activity_type: string;
  ayah_start: number;
  ayah_end: number;
  score?: number | string | null;
  teacher_note?: string | null;
};

export type TahfidzTarget = RowRecord & {
  id: string;
  student_id: string;
  target_juz: number | string;
  target_date?: string | null;
};

export type Subject = RowRecord & {
  id: string;
  code: string;
  name: string;
  category?: string;
  active: boolean;
};

export type Grade = RowRecord & {
  id: string;
  created_at?: string;
  student_id: string;
  subject_id?: string;
  subject_code?: string;
  subject_name?: string;
  academic_year?: string;
  semester?: string;
  assessment_type?: string;
  score?: number | string | null;
  grade?: string | null;
  teacher_note?: string | null;
  published?: boolean;
};

export type AcademicReport = RowRecord & {
  id: string;
  student_id: string;
  academic_year?: string;
  report_type: string;
  semester?: string;
  status: string;
};

export type SessionUser = RowRecord & {
  id: string;
  email: string;
  name: string;
  role: string;
  status: string;
};

export type SessionResponse = {
  data?: SessionUser;
};

export type GuardianCandidate = RowRecord & {id:string;email:string;display_name:string;role:string;status:string};

export type NotificationCandidate = {id:string;email:string;display_name:string;role:string;status:string};
