import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { accessCookie } from "../../lib/server";
import LoginForm from "./LoginForm";
export default async function LoginPage(){const jar=await cookies();if(jar.get(accessCookie)){redirect('/dashboard');}return <LoginForm/>}
