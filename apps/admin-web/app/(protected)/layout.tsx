import {cookies} from "next/headers";
import {redirect} from "next/navigation";
import AppShell from "../../components/AppShell";
import {accessCookie,refreshCookie} from "../../lib/server";
export default async function ProtectedLayout({children}:{children:React.ReactNode}){const jar=await cookies();if(!jar.get(accessCookie)&&!jar.get(refreshCookie)){redirect('/login');}return <AppShell>{children}</AppShell>}
