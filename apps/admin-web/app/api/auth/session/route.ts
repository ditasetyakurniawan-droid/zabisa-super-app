import {cookies} from "next/headers";
import {NextResponse} from "next/server";
import {accessCookie,backendURL,cookieOptions,refreshCookie} from "../../../../lib/server";
import {isInternalRole} from "../../../../lib/rbac";

async function me(token:string){return fetch(`${backendURL()}/api/v1/auth/me`,{headers:{Authorization:`Bearer ${token}`,"X-Request-ID":crypto.randomUUID()},cache:'no-store'})}
async function rotate(refreshToken:string){const up=await fetch(`${backendURL()}/api/v1/auth/refresh`,{method:'POST',headers:{'Content-Type':'application/json','X-Request-ID':crypto.randomUUID()},body:JSON.stringify({refresh_token:refreshToken}),cache:'no-store'});if(!up.ok){return null;}return (await up.json())?.data as {access_token:string;refresh_token:string;expires_in:number}|undefined}

export async function GET(){
  const jar=await cookies();let at=jar.get(accessCookie)?.value;const rt=jar.get(refreshCookie)?.value;let rotated:Awaited<ReturnType<typeof rotate>>=null;
  if(!at&&rt){rotated=await rotate(rt);at=rotated?.access_token}
  if(!at){return NextResponse.json({error:{code:'UNAUTHORIZED',message:'Authentication required'}},{status:401});}
  let up=await me(at);
  if(up.status===401&&rt){rotated=await rotate(rt);if(rotated){at=rotated.access_token;up=await me(at)}}
  const body=await up.json().catch(()=>({error:{code:'SESSION_FAILED',message:'Could not validate session'}}));
  if(!up.ok||!body?.data){const res=NextResponse.json(body,{status:up.status||401});res.cookies.delete(accessCookie);res.cookies.delete(refreshCookie);return res}
  if(!isInternalRole(String(body.data.role||''))){const res=NextResponse.json({error:{code:'BACKOFFICE_FORBIDDEN',message:'Backoffice access is not granted for this role.'}},{status:403});res.cookies.delete(accessCookie);res.cookies.delete(refreshCookie);return res}
  const res=NextResponse.json(body,{status:200});
  if(rotated){res.cookies.set(accessCookie,rotated.access_token,cookieOptions(rotated.expires_in||900));res.cookies.set(refreshCookie,rotated.refresh_token,cookieOptions(30*24*60*60))}
  return res;
}
