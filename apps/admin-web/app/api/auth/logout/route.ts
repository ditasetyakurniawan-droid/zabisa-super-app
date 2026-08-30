import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { accessCookie, backendURL, refreshCookie } from "../../../../lib/server";
export async function POST(){const jar=await cookies();const at=jar.get(accessCookie)?.value;if(at){await fetch(`${backendURL()}/api/v1/auth/logout`,{method:"POST",headers:{Authorization:`Bearer ${at}`},cache:"no-store"}).catch(()=>undefined)};const res=NextResponse.json({data:{logged_out:true},error:null});res.cookies.delete(accessCookie);res.cookies.delete(refreshCookie);return res}
