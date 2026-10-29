import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, x-app-role"};
const UPPER="ABCDEFGHJKLMNPQRSTUVWXYZ",LOWER="abcdefghijkmnopqrstuvwxyz",DIGITS="23456789",SYMBOLS="!@#$%*-_",ALL=UPPER+LOWER+DIGITS+SYMBOLS;
function ri(max:number){const a=new Uint32Array(1);crypto.getRandomValues(a);return a[0]%max}
function pick(s:string){return s[ri(s.length)]}
function tempPassword(length=16){const a=[pick(UPPER),pick(LOWER),pick(DIGITS),pick(SYMBOLS)];while(a.length<length)a.push(pick(ALL));for(let i=a.length-1;i>0;i--){const j=ri(i+1);[a[i],a[j]]=[a[j],a[i]]}return a.join("")}
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}})}

Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");
 if(!token)return json({error:"Unauthorized"},401);
 const admin=createClient(url,service,{auth:{persistSession:false}});
 const {data:userData,error:userErr}=await admin.auth.getUser(token);
 if(userErr||!userData.user)return json({error:"Unauthorized"},401);
 const actorId=userData.user.id;
 const {data:actor,error:actorErr}=await admin.from("profiles").select("id,role,is_active").eq("id",actorId).single();
 if(actorErr||!actor?.is_active)return json({error:"الحساب غير مفعل"},403);
 const requestedRole=(req.headers.get("x-app-role")||actor.role).trim();
 const {data:activeRole}=await admin.from("user_roles").select("role").eq("profile_id",actorId).eq("role",requestedRole).eq("is_active",true).maybeSingle();
 if(!activeRole)return json({error:"الدور النشط غير مسموح لهذا الحساب"},403);
 const body=await req.json();
 const civilId=String(body.civil_id||"").trim(),fullName=String(body.full_name||"").trim(),phone=body.phone?String(body.phone).trim():null,role=String(body.role||"").trim();
 const schoolId=body.school_id||null,stage=body.stage?String(body.stage).trim():null;
 if(!civilId||!fullName||!role)return json({error:"الرقم المدني والاسم والدور مطلوبة"},400);
 if(!/^\d{6,20}$/.test(civilId))return json({error:"صيغة الرقم المدني غير صحيحة"},400);
 const allowed:Record<string,string[]>={admin:["first_supervisor","stage_coordinator","supervisor","school_manager"],supervisor:["senior_teacher","teacher"],senior_teacher:["teacher"]};
 if(!(allowed[String(activeRole.role)]||[]).includes(role))return json({error:"لا توجد صلاحية لإنشاء هذا النوع من الحسابات من الدور النشط"},403);
 const password=tempPassword(16),email=`${civilId}@science-guidance.local`;
 const {data:created,error:createErr}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{civil_id:civilId,full_name:fullName}});
 if(createErr||!created.user)return json({error:createErr?.message||"تعذر إنشاء الحساب"},400);
 const uid=created.user.id;
 try{
   const {data:linked,error:linkErr}=await admin.rpc("service_link_created_system_user_atomic",{
     p_uid:uid,p_actor_id:actorId,p_actor_role:String(activeRole.role),p_civil_id:civilId,p_full_name:fullName,p_phone:phone,
     p_role:role,p_school_id:schoolId,p_stage:stage,p_email:body.email||null,p_job_title:body.job_title||null,
     p_appointment_date:body.appointment_date||null,p_work_type:body.work_type==="paid"?"paid":"permanent"
   });
   if(linkErr)throw linkErr;
   const teacherId=(linked as any)?.teacher_id||null;
   if(teacherId && (role==="teacher"||role==="senior_teacher")){
     const gradeDate=body.grade_acquired_date||null,workStart=body.work_start_date||null;
     const {error:datesErr}=await admin.from("teacher_records").update({grade_acquired_date:gradeDate,work_start_date:workStart}).eq("id",teacherId);
     if(datesErr)throw datesErr;
   }
   return json({success:true,user_id:uid,civil_id:civilId,temporary_password:password,must_change_password:true,...(linked||{})});
 }catch(e){
   await admin.auth.admin.deleteUser(uid);
   return json({error:e instanceof Error?e.message:String(e)},400);
 }
});