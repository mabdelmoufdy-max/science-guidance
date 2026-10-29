-- استرجاع v220c: يعيد الدالتين والسياسة من private.v220c_backup.
do $$ declare r record; begin
 for r in select * from private.v220c_backup where kind='function' loop execute r.def; end loop;
 for r in select * from private.v220c_backup where kind='policy' loop
  execute format('alter policy %I on public.coordinator_school_approvals using (%s) with check (%s)', r.name, r.qual, r.with_check);
 end loop;
end $$;
-- دالتا الحافة: أعد نشر edge/execute-teacher-delegation.v3.ts (باسم execute-teacher-delegation) و edge/create-system-user.v10.ts (باسم create-system-user).
