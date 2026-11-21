-- v433 استرجاع (يُشغَّل من SQL Editor): يعيد دوال البوابة إلى قراءة الأعمدة القديمة ثم يزيل السجل والدوال الجديدة.
-- تنبيه: يفقد إعدادات المفاتيح الدقيقة (دور/مرحلة). المفتاح العام باقٍ في أعمدة teacher_portal_settings (مرآة).

select private.v433_patch('public.admin_revert_action',
  E'  elsif a.action = ''cc_portal_feature'' then\n    perform public.admin_set_portal_feature(a.old_data->>''feature'', a.old_data->>''role'', a.old_data->>''stage'', coalesce((a.old_data->>''open'')::boolean, true), coalesce(a.old_data->>''message'', ''''), v_r);\n  elsif a.action = ''cc_portal_preset'' then\n    for e in select * from jsonb_array_elements(a.old_data->''rows'') loop\n      perform private.pf_set(e->>''feature'', e->>''role'', e->>''stage'', coalesce((e->>''open'')::boolean, true), e->>''message'', true);\n    end loop;\n  elsif a.action = ''cc_permissions'' then',
  E'  elsif a.action = ''cc_permissions'' then');
select private.v433_patch('private.run_scheduled_flags',
  E'  n := n + private.run_portal_schedule();\n  return n;',
  E'  return n;');
select private.v433_patch('private.run_scheduled_flags',
  'perform private.pf_set(''timetable'',''all'',''all'',r.value,null,false);',
  'update public.teacher_portal_settings set timetable_open = r.value, updated_at = now() where id = 1;');
select private.v433_patch('private.run_scheduled_flags',
  'perform private.pf_set(''editing'',''all'',''all'',r.value,null,false);',
  'update public.teacher_portal_settings set editing_open = r.value, updated_at = now() where id = 1;');
select private.v433_patch('public.teacher_portal_admin_settings',
  'perform private.pf_set(''editing'',''all'',''all'',p_open,null,false);',
  'update public.teacher_portal_settings set editing_open = p_open, updated_at = now() where id = 1;');
select private.v433_patch('public.admin_set_flag',
  'perform private.pf_set(''timetable'',''all'',''all'',p_value,null,false);',
  'update public.teacher_portal_settings set timetable_open = p_value, updated_at = now() where id = 1;');
select private.v433_patch('public.admin_set_flag',
  'perform private.pf_set(''editing'',''all'',''all'',p_value,null,false);',
  'update public.teacher_portal_settings set editing_open = p_value, updated_at = now() where id = 1;');
select private.v433_patch('public.teacher_portal_sup_submit',
  'v_open := private.pf_open_civil(''editing'',''supervisor'',p_civil);',
  'select editing_open into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_submit',
  'v_open := private.pf_open_civil(''editing'',''teacher'',p_civil);',
  'select editing_open into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_school_update',
  'v_open := private.pf_open(''school_edit'',''supervisor'',(c ->> ''school_id'')::uuid,null);',
  'select coalesce(school_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_remove_class',
  'v_open := private.pf_open(''classes'',''supervisor'',v_school,null);',
  'select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_add_class',
  'v_open := private.pf_open(''classes'',''supervisor'',v_school,null);',
  'select coalesce(classes_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_unassign',
  'v_open := private.pf_open(''assign'',''supervisor'',v_school,null);',
  'select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_assign',
  'v_open := private.pf_open(''assign'',''supervisor'',v_school,null);',
  'select coalesce(assign_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_long_leave_request',
  'v_open := private.pf_open(''leaves_long'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_short_leave_cancel',
  'v_open := private.pf_open(''leaves_short'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_short_leave_add',
  'v_open := private.pf_open(''leaves_short'', case when x ->> ''role'' = ''teacher'' then ''teacher'' else ''supervisor'' end, nullif(x ->> ''school_id'','''')::uuid, (x ->> ''teacher_id'')::uuid);',
  'select coalesce(leaves_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_timetable_save',
  'v_open := private.pf_open(''timetable'',''supervisor'',v_school,null);',
  'select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_timetable_save',
  'v_open := private.pf_open(''timetable'',''teacher'',null,(c ->> ''teacher_id'')::uuid);',
  'select coalesce(timetable_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_paid_ws_set',
  'v_open := private.pf_open(''paid_ws'',''teacher'',null,(c ->> ''teacher_id'')::uuid);',
  'select coalesce(paid_ws_edit_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_sup_fill_missing',
  'v_open := private.pf_open(''fill'',''supervisor'',(c ->> ''school_id'')::uuid,null);',
  'select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;');
select private.v433_patch('public.teacher_portal_fill_missing',
  'v_open := private.pf_open(''fill'',''teacher'',null,(c ->> ''teacher_id'')::uuid);',
  'select coalesce(fill_open, true) into v_open from public.teacher_portal_settings where id = 1;');

drop trigger if exists trg_pf_mirror on public.portal_feature_flags;
drop function if exists public.teacher_portal_features();
drop function if exists public.admin_portal_features();
drop function if exists public.admin_set_portal_feature(text,text,text,boolean,text,text);
drop function if exists public.admin_set_portal_preset(text,text);
drop function if exists public.admin_portal_schedule_add(text,text,text,boolean,timestamptz,text);
drop function if exists public.admin_portal_schedule_cancel(uuid);
drop function if exists private.run_portal_schedule();
drop function if exists private.pf_mirror();
drop function if exists private.pf_set(text,text,text,boolean,text,boolean);
drop function if exists private.pf_open_civil(text,text,text);
drop function if exists private.pf_open(text,text,uuid,uuid);
drop function if exists private.v433_patch(text,text,text);
-- الجداول تُترك للأرشيف: drop table public.portal_feature_schedule, public.portal_feature_flags, public.portal_feature_catalog;
