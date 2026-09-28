"use client";

import { useState } from "react";

import { Sidebar } from "@/components/layout/sidebar";
import { Topbar } from "@/components/layout/topbar";

export function DashboardShell({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {

  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  function closeSidebar() {
    setIsSidebarOpen(false);
  }

  function toggleSidebar() {
    setIsSidebarOpen((current) => !current);
  }

  return (
    <div className="min-h-screen">
      <Sidebar isOpen={isSidebarOpen} onClose={closeSidebar} onMenuToggle={toggleSidebar}/>

      <div className="lg:pl-64">
        <Topbar isSidebarOpen={isSidebarOpen} onMenuToggle={toggleSidebar}/>
        <main className="mx-auto max-w-[1600px] px-4 py-6 sm:px-6 lg:px-8">
          {children}
        </main>
      </div>
    </div>
  );
}
