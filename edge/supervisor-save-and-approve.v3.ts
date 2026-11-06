import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-app-role",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

function cleanId(value: unknown) {
  return String(value ?? "").trim().slice(0, 100);
}

function numberValue(value: unknown, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function nonNegativeInteger(value: unknown) {
  const result = numberValue(value, -1);
  return Number.isInteger(result) && result >= 0 ? result : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!url || !serviceKey) return json({ error: "تعذر تهيئة خدمة الاعتماد" }, 500);
  if (!token) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const actorId = userData.user.id;

  const [{ data: profile, error: profileError }, { data: roleRow, error: roleError }] = await Promise.all([
    admin.from("profiles").select("id,full_name,is_active").eq("id", actorId).maybeSingle(),
    admin.from("user_roles").select("role").eq("profile_id", actorId).eq("role", "supervisor").eq("is_active", true).maybeSingle(),
  ]);
  if (profileError || !profile?.is_active) return json({ error: "الحساب غير مفعل" }, 403);
  if (roleError || !roleRow) return json({ error: "هذه العملية متاحة للمشرف المكلّف فقط" }, 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "صيغة الطلب غير صحيحة" }, 400);
  }

  const action = cleanId(body.action || "save_and_approve");
  const supportedActions = new Set([
    "save_and_approve",
    "create_class_and_approve",
    "save_subject_periods_and_approve",
    "assign_class_and_approve",
  ]);
  if (!supportedActions.has(action)) return json({ error: "إجراء غير مدعوم" }, 400);

  const schoolId = cleanId(body.school_id);
  const academicYearId = cleanId(body.academic_year_id);
  const termId = cleanId(body.term_id);
  if (!schoolId || !academicYearId || !termId) {
    return json({ error: "يلزم تحديد المدرسة والسنة والفترة الدراسية" }, 400);
  }

  const [{ data: supervisor, error: supervisorError }, { data: term, error: termError }] = await Promise.all([
    admin.from("supervisors").select("id").eq("profile_id", actorId).eq("active", true).maybeSingle(),
    admin.from("terms").select("id,academic_year_id,is_active").eq("id", termId).eq("academic_year_id", academicYearId).eq("is_active", true).maybeSingle(),
  ]);
  if (supervisorError || !supervisor?.id) return json({ error: "لا يوجد سجل مشرف نشط لهذا الحساب" }, 403);
  if (termError || !term) return json({ error: "الفترة الدراسية غير مفعلة أو لا تتبع السنة المحددة" }, 400);

  const { data: school, error: schoolError } = await admin
    .from("schools")
    .select("id,name,stage,supervisor_id,class_count")
    .eq("id", schoolId)
    .maybeSingle();
  if (schoolError || !school) return json({ error: "المدرسة غير موجودة" }, 404);
  if (school.supervisor_id !== supervisor.id) {
    return json({ error: "لا يمكنك إدخال الفصول أو اعتمادها إلا لمدرسة مسندة إليك" }, 403);
  }

  let mutation: Record<string, unknown> = { action };

  if (action === "create_class_and_approve") {
    const input = (body.class && typeof body.class === "object" ? body.class : {}) as Record<string, unknown>;
    const stage = cleanId(input.stage);
    const grade = cleanId(input.grade);
    const className = cleanId(input.class_name);
    const leaderTeacherId = cleanId(input.leader_teacher_id) || null;
    const gradeOrderRaw = input.grade_order;
    const gradeOrder = gradeOrderRaw === null || gradeOrderRaw === undefined || gradeOrderRaw === ""
      ? null
      : nonNegativeInteger(gradeOrderRaw);
    if (!stage || !grade || !className) return json({ error: "المرحلة والصف واسم الفصل مطلوبة" }, 400);
    if (stage !== String(school.stage || "")) return json({ error: "مرحلة الفصل يجب أن تطابق مرحلة المدرسة" }, 400);
    if (gradeOrderRaw !== null && gradeOrderRaw !== undefined && gradeOrderRaw !== "" && gradeOrder === null) {
      return json({ error: "ترتيب الصف غير صحيح" }, 400);
    }
    if (leaderTeacherId) {
      const { data: leader, error: leaderError } = await admin
        .from("teacher_records")
        .select("id,home_school_id,active")
        .eq("id", leaderTeacherId)
        .maybeSingle();
      if (leaderError || !leader?.active || leader.home_school_id !== schoolId) {
        return json({ error: "رائد الفصل يجب أن يكون معلمًا نشطًا في المدرسة نفسها" }, 400);
      }
    }
    const { data: existingClass, error: existingClassError } = await admin
      .from("school_classes")
      .select("id")
      .eq("school_id", schoolId)
      .eq("academic_year_id", academicYearId)
      .eq("term_id", termId)
      .eq("grade", grade)
      .eq("class_name", className)
      .maybeSingle();
    if (existingClassError) return json({ error: "تعذر التحقق من تكرار الفصل" }, 500);
    if (existingClass?.id) return json({ error: "هذا الفصل مسجل بالفعل لهذه الفترة الدراسية" }, 409);
    const { data: createdClass, error: createClassError } = await admin
      .from("school_classes")
      .insert({
        school_id: schoolId,
        academic_year_id: academicYearId,
        term_id: termId,
        stage,
        grade,
        class_name: className,
        science_periods: 0,
        grade_order: gradeOrder,
        leader_teacher_id: leaderTeacherId,
      })
      .select("id,stage,grade,class_name")
      .single();
    if (createClassError || !createdClass) return json({ error: createClassError?.message || "تعذر حفظ الفصل" }, 500);
    mutation = { action, class: createdClass };
  }

  if (action === "save_subject_periods_and_approve") {
    const classId = cleanId(body.class_id);
    const rawUpdates = Array.isArray(body.subject_periods) ? body.subject_periods : [];
    if (!classId || !rawUpdates.length) return json({ error: "حدد الفصل وحصص المواد أولًا" }, 400);
    if (rawUpdates.length > 20) return json({ error: "عدد مواد غير صالح" }, 400);
    const updates = rawUpdates.map((item) => {
      const row = item && typeof item === "object" ? item as Record<string, unknown> : {};
      return { id: cleanId(row.id), weekly_periods: nonNegativeInteger(row.weekly_periods) };
    });
    if (updates.some((item) => !item.id || item.weekly_periods === null)) {
      return json({ error: "حصص المواد يجب أن تكون أرقامًا صحيحة غير سالبة" }, 400);
    }
    if (new Set(updates.map((item) => item.id)).size !== updates.length) return json({ error: "مواد مكررة في الطلب" }, 400);
    const { data: classRow, error: classError } = await admin
      .from("school_classes")
      .select("id,school_id,academic_year_id,term_id")
      .eq("id", classId)
      .maybeSingle();
    if (classError || !classRow || classRow.school_id !== schoolId || classRow.academic_year_id !== academicYearId || classRow.term_id !== termId) {
      return json({ error: "الفصل لا يتبع المدرسة أو الفترة المحددة" }, 400);
    }
    const ids = updates.map((item) => item.id);
    const { data: requirements, error: requirementsError } = await admin
      .from("class_subject_requirements")
      .select("id")
      .eq("class_id", classId)
      .in("id", ids);
    if (requirementsError || (requirements || []).length !== ids.length) {
      return json({ error: "تتضمن العملية موادًا لا تخص هذا الفصل" }, 400);
    }
    const results = await Promise.all(updates.map((item) => admin
      .from("class_subject_requirements")
      .update({ weekly_periods: item.weekly_periods })
      .eq("id", item.id)
      .eq("class_id", classId)));
    const updateError = results.find((result) => result.error)?.error;
    if (updateError) return json({ error: updateError.message }, 500);
    mutation = { action, class_id: classId, updated_subjects: updates.length };
  }

  if (action === "assign_class_and_approve") {
    const classId = cleanId(body.class_id);
    const teacherId = cleanId(body.teacher_id);
    const subjectId = cleanId(body.subject_id);
    if (!classId || !teacherId || !subjectId) return json({ error: "حدد المعلم والفصل والمادة أولًا" }, 400);
    const [{ data: classRow, error: classError }, { data: teacher, error: teacherError }] = await Promise.all([
      admin.from("school_classes").select("id,school_id,academic_year_id,term_id").eq("id", classId).maybeSingle(),
      admin.from("teacher_records").select("id,home_school_id,active").eq("id", teacherId).maybeSingle(),
    ]);
    if (classError || !classRow || classRow.school_id !== schoolId || classRow.academic_year_id !== academicYearId || classRow.term_id !== termId) {
      return json({ error: "الفصل لا يتبع المدرسة أو الفترة المحددة" }, 400);
    }
    if (teacherError || !teacher?.active || teacher.home_school_id !== schoolId) {
      return json({ error: "المعلم يجب أن يكون نشطًا ومسجلًا في المدرسة نفسها" }, 400);
    }
    const { data: requirement, error: requirementError } = await admin
      .from("class_subject_requirements")
      .select("id,weekly_periods,subject_id")
      .eq("class_id", classId)
      .eq("subject_id", subjectId)
      .maybeSingle();
    if (requirementError || !requirement) return json({ error: "المادة لا تخص هذا الفصل" }, 400);
    if (numberValue(requirement.weekly_periods) <= 0) return json({ error: "حدد حصص المادة الأسبوعية قبل الإسناد" }, 400);
    const { data: assigned, error: assignedError } = await admin
      .from("teaching_assignments")
      .select("id")
      .eq("class_id", classId)
      .eq("subject_id", subjectId)
      .eq("term_id", termId)
      .maybeSingle();
    if (assignedError) return json({ error: "تعذر التحقق من الإسناد الحالي" }, 500);
    if (assigned?.id) return json({ error: "المادة مسندة بالفعل لهذا الفصل" }, 409);
    const { data: createdAssignment, error: createAssignmentError } = await admin
      .from("teaching_assignments")
      .insert({
        teacher_id: teacherId,
        class_id: classId,
        subject_id: subjectId,
        academic_year_id: academicYearId,
        term_id: termId,
        weekly_periods: numberValue(requirement.weekly_periods),
      })
      .select("id,weekly_periods")
      .single();
    if (createAssignmentError || !createdAssignment) return json({ error: createAssignmentError?.message || "تعذر حفظ الإسناد" }, 500);
    mutation = { action, assignment: createdAssignment };
  }

  const [{ count: detailedClasses, error: classesError }, { data: existingSubmission, error: submissionReadError }] = await Promise.all([
    admin.from("school_classes").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("term_id", termId),
    admin.from("school_submissions").select("id,row_version").eq("school_id", schoolId).eq("term_id", termId).maybeSingle(),
  ]);
  if (classesError || submissionReadError) return json({ error: "تعذر التحقق من بيانات المدرسة قبل الاعتماد" }, 500);
  if (Number(detailedClasses || 0) === 0 && Number(school.class_count || 0) === 0) {
    return json({ error: "أدخل عدد الفصول أو فصلًا واحدًا على الأقل قبل الاعتماد" }, 400);
  }

  let assignedClasses = 0;
  if (Number(detailedClasses || 0) > 0) {
    const { data: classRows, error: classRowsError } = await admin
      .from("school_classes")
      .select("id")
      .eq("school_id", schoolId)
      .eq("term_id", termId);
    if (classRowsError) return json({ error: "تعذر قراءة الفصول قبل الاعتماد" }, 500);
    const classIds = (classRows || []).map((row) => row.id);
    if (classIds.length) {
      const { count, error: assignmentsError } = await admin
        .from("teaching_assignments")
        .select("class_id", { count: "exact", head: true })
        .eq("term_id", termId)
        .in("class_id", classIds);
      if (assignmentsError) return json({ error: "تعذر التحقق من إسناد الفصول قبل الاعتماد" }, 500);
      assignedClasses = Number(count || 0);
    }
  }

  const declaredClasses = Math.max(Number(school.class_count || 0), Number(detailedClasses || 0));
  const now = new Date().toISOString();
  const submissionPatch = {
    status: "approved",
    submitted_by: actorId,
    submitted_at: now,
    approved_by: actorId,
    approved_at: now,
    return_reason: null,
    entry_source: "supervisor",
    intervention_reason: "إدخال وحفظ واعتماد مباشر بواسطة المشرف المكلّف بالمدرسة",
    last_changed_by: actorId,
    updated_at: now,
  };

  let submission;
  if (existingSubmission?.id) {
    const { data, error } = await admin
      .from("school_submissions")
      .update({ ...submissionPatch, row_version: Number(existingSubmission.row_version || 0) + 1 })
      .eq("id", existingSubmission.id)
      .select("id,row_version")
      .single();
    if (error) return json({ error: error.message }, 500);
    submission = data;
  } else {
    const { data, error } = await admin
      .from("school_submissions")
      .insert({
        school_id: schoolId,
        academic_year_id: academicYearId,
        term_id: termId,
        ...submissionPatch,
        row_version: 1,
      })
      .select("id,row_version")
      .single();
    if (error) return json({ error: error.message }, 500);
    submission = data;
  }

  const { error: schoolUpdateError } = await admin
    .from("schools")
    .update({ status: "approved", class_count: declaredClasses })
    .eq("id", schoolId);
  if (schoolUpdateError) return json({ error: schoolUpdateError.message }, 500);

  await admin.from("audit_log").insert({
    actor_profile_id: actorId,
    actor_role: "supervisor",
    action: "supervisor_direct_save_and_approve",
    entity_type: "school_submission",
    entity_id: submission.id,
    new_data: {
      school_id: schoolId,
      action,
      detailed_classes: Number(detailedClasses || 0),
      assigned_classes: assignedClasses,
    },
  });

  return json({
    success: true,
    school_id: schoolId,
    school_name: school.name,
    submission_id: submission.id,
    row_version: submission.row_version,
    detailed_classes: Number(detailedClasses || 0),
    declared_classes: declaredClasses,
    assigned_classes: assignedClasses,
    status: "approved",
    mutation,
  });
});
