import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";
import { accessCookie, backendURL, cookieOptions, refreshCookie } from "../../../../lib/server";

type Ctx={params:Promise<{path:string[]}>};
async function forward(req:NextRequest,path:string[],token?:string){
  const url=new URL(`${backendURL()}/api/${path.join("/")}`); req.nextUrl.searchParams.forEach((v,k)=>url.searchParams.append(k,v));
  const headers=new Headers();
  const ct=req.headers.get("content-type");
  if(ct)headers.set("content-type",ct);
  for(const h of ["idempotency-key","x-request-id","traceparent","user-agent","x-forwarded-for"]){
    const v=req.headers.get(h);
    if(v)headers.set(h,v);
  }
  if(!headers.get("x-forwarded-for")){
    const forwarded=req.headers.get("x-real-ip");
    if(forwarded)headers.set("x-forwarded-for",forwarded);
  }
  if(token)headers.set("authorization",`Bearer ${token}`);
  headers.set("x-request-id",headers.get("x-request-id")||crypto.randomUUID());
  const hasBody=!['GET','HEAD'].includes(req.method); const body=hasBody?await req.arrayBuffer():undefined;
  return fetch(url,{method:req.method,headers,body,cache:"no-store",redirect:"manual"});
}
async function refresh(rt:string){const up=await fetch(`${backendURL()}/api/v1/auth/refresh`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({refresh_token:rt}),cache:"no-store"});if(!up.ok)return null;return (await up.json())?.data as {access_token:string;refresh_token:string;expires_in:number}|undefined}
async function handle(req:NextRequest,ctx:Ctx){const {path}=await ctx.params;const jar=await cookies();let at=jar.get(accessCookie)?.value;const rt=jar.get(refreshCookie)?.value;let up=await forward(req,path,at);let rotated:Awaited<ReturnType<typeof refresh>>=null;if(up.status===401&&rt){rotated=await refresh(rt);if(rotated){at=rotated.access_token;up=await forward(req,path,at)}}const headers=new Headers();const contentType=up.headers.get("content-type");if(contentType)headers.set("content-type",contentType);const res=new NextResponse(await up.arrayBuffer(),{status:up.status,headers});if(rotated){res.cookies.set(accessCookie,rotated.access_token,cookieOptions(rotated.expires_in||900));res.cookies.set(refreshCookie,rotated.refresh_token,cookieOptions(30*24*60*60))}if(up.status===401&&!rotated){res.cookies.delete(accessCookie);res.cookies.delete(refreshCookie)}return res}
export const GET=handle;export const POST=handle;export const PATCH=handle;export const PUT=handle;export const DELETE=handle;
