import {NextRequest,NextResponse} from "next/server";
import {accessCookie,backendURL,cookieOptions,refreshCookie} from "../../../../lib/server";
import {isInternalRole} from "../../../../lib/rbac";

export async function POST(req:NextRequest){
  const payload=await req.text();
  const requestId=crypto.randomUUID();
  const upstream=await fetch(`${backendURL()}/api/v1/auth/login`,{method:"POST",headers:{"Content-Type":"application/json","X-Request-ID":requestId},body:payload,cache:"no-store"});
  const body=await upstream.json();
  if(!upstream.ok||!body?.data?.access_token)return NextResponse.json(body,{status:upstream.status});
  const role=String(body?.data?.user?.role||'');
  if(!isInternalRole(role)){
    await fetch(`${backendURL()}/api/v1/auth/logout`,{method:'POST',headers:{Authorization:`Bearer ${body.data.access_token}`,"X-Request-ID":requestId},cache:'no-store'}).catch(()=>undefined);
    return NextResponse.json({error:{code:'BACKOFFICE_FORBIDDEN',message:'Akun ini tidak memiliki akses Backoffice Zabisa.'}},{status:403});
  }
  const res=NextResponse.json(body,{status:200});
  res.cookies.set(accessCookie,body.data.access_token,cookieOptions(Number(body.data.expires_in||900)));
  res.cookies.set(refreshCookie,body.data.refresh_token,cookieOptions(30*24*60*60));
  return res;
}
