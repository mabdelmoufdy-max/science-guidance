import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const target='https://xehjwzszhsaqdqmcatum.supabase.co/functions/v1/school-data-form?v=20260823-1545';
Deno.serve((req:Request)=>{
  if(req.method!=='GET'&&req.method!=='HEAD') return new Response('Method Not Allowed',{status:405});
  return Response.redirect(target,302);
});
