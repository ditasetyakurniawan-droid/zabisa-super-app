import type {Metadata} from "next";
import Providers from "./providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "Zabisa Backoffice",
  description: "Administration console for Zabisa Mobile",
};

export default function RootLayout({children}: Readonly<{children: React.ReactNode}>) {
  return (
    <html lang="id">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
