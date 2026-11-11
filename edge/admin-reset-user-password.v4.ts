import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, x-app-role"};
const UPPER="ABCDEFGHJKLMNPQRSTUVWXYZ";
const LOWER="abcdefghijkmnopqrstuvwxyz";
const DIGITS="23456789";
const SYMBOLS="!@#$%*-_";
const ALL=UPPER+LOWER+DIGITS+SYMBOLS;
function randomIndex(max:number){const a=new Uint32Array(1);crypto.getRandomValues(a);return a[0]%max}
function pick(chars:string){return chars[randomIndex(chars.length)]}
function generateTemporaryPassword(length=16){const out=[pick(UPPER),pick(LOWER),pick(DIGITS),pick(SYMBOLS)];while(out.length<length)out.push(pick(ALL));for(let i=out.length-1;i>0;i--){const j=randomIndex(i+1);[out[i],out[j]]=[out[j],out[i]]}return out.join("")}
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}})}
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 if(req.method!=="POST") return json({error:"Method not allowed"},405);
 const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,""); if(!token)return json({error:"Unauthorized"},401);
 const admin=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
 const {data:u,error:ue}=await admin.auth.getUser(token); if(ue||!u.user)return json({error:"Unauthorized"},401);
 const {data:actor,error:ae}=await admin.from("profiles").select("id,role,is_active").eq("id",u.user.id).single();
 if(ae||!actor?.is_active) return json({error:"الحساب غير مفعل"},403);
 const requestedRole=(req.headers.get("x-app-role")||actor.role).trim();
 const {data:activeRoleRow}=await admin.from("user_roles").select("role").eq("profile_id",actor.id).eq("role",requestedRole).eq("is_active",true).maybeSingle();
 if(!activeRoleRow||activeRoleRow.role!=="admin") return json({error:"هذه العملية متاحة لمدير النظام عند تفعيل دور مدير النظام فقط"},403);
 const body=await req.json(); const targetId=String(body.profile_id||""); if(!targetId)return json({error:"الحساب مطلوب"},400);
 const {data:target,error:te}=await admin.from("profiles").select("id,full_name,civil_id,is_active").eq("id",targetId).single(); if(te||!target)return json({error:"الحساب غير موجود"},404);
 const temporaryPassword=generateTemporaryPassword(16);
 const {error:pe}=await admin.auth.admin.updateUserById(targetId,{password:temporaryPassword}); if(pe)return json({error:pe.message},400);
 const {error:fe}=await admin.from("profiles").update({must_change_password:true}).eq("id",targetId); if(fe)return json({error:fe.message},400);
 await admin.from("audit_log").insert({actor_profile_id:actor.id,actor_role:"admin",action:"reset_password",entity_type:"profile",entity_id:targetId,new_data:{temporary_password_policy:"random_strong_16_force_change",force_change:true}});
 return json({success:true,temporary_password:temporaryPassword,full_name:target.full_name,civil_id:target.civil_id,must_change_password:true});
});