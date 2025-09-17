import React from 'react';
import '../globals.css';
import { ReactNode } from 'react';

export const metadata = {
  title: 'sola-showcase',
  description: 'Bilingual portfolio — FR/EN',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen bg-white text-gray-900 dark:bg-neutral-950 dark:text-neutral-100">
        <main className="mx-auto max-w-5xl p-6">{children}</main>
      </body>
    </html>
  );
}