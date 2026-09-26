import {
  BarChart3,
  CreditCard,
  LayoutDashboard,
  ReceiptText,
  Wallet,
} from "lucide-react";

export const navigationItems = [
  {
    label: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
  },
  {
    label: "Transactions",
    href: "/dashboard/transactions",
    icon: ReceiptText,
  },
  {
    label: "Accounts",
    href: "/dashboard/accounts",
    icon: Wallet,
  },
  {
    label: "Budgets",
    href: "/dashboard/budgets",
    icon: CreditCard,
  },
  {
    label: "Analytics",
    href: "/dashboard/analytics",
    icon: BarChart3,
  },
] as const;
