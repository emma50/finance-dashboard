import { format } from "date-fns";

export function formatTransactionDate(value: string | Date) {
  return format(new Date(value), "dd MMM yyyy");
}
