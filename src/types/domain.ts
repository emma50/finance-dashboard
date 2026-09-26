export const ACCOUNT_TYPES = [
  "current",
  "savings",
  "cash",
  "credit_card",
] as const;

export type AccountType = (typeof ACCOUNT_TYPES)[number];

export const TRANSACTION_TYPES = ["income", "expense", "transfer"] as const;

export type TransactionType = (typeof TRANSACTION_TYPES)[number];

export const TRANSACTION_STATUSES = [
  "pending",
  "completed",
  "cancelled",
] as const;

export type TransactionStatus = (typeof TRANSACTION_STATUSES)[number];
