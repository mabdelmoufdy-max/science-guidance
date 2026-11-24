-- استرجاع v461: إعادة my_coordinator_scope إلى نسخة v458 (بلا is_gc). آمن؛ الواجهة تتجاهل غياب الحقل.
create or replace function public.my_coordinator_scope()
returns jsonb language plpgsql stable security definer set search_path to 'public','pg_temp' as $$
begin
  if auth.uid() is null then return jsonb_build_object('general', false, 'stages', '[]'::jsonb); end if;
  return jsonb_build_object(
    'general', private.current_app_role()::text = 'stage_coordinator' and private.is_general_coordinator(auth.uid()),
    'stages', coalesce((select jsonb_agg(distinct sca.stage) from public.stage_coordinator_assignments sca
                          join public.supervisors s on s.id = sca.supervisor_id
                         where s.profile_id = auth.uid() and s.active and sca.active), '[]'::jsonb));
end $$;
revoke all on function public.my_coordinator_scope() from public, anon;
grant execute on function public.my_coordinator_scope() to authenticated;
