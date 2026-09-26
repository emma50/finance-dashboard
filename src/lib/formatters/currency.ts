const currencyFormatters = new Map<string, Intl.NumberFormat>();

export function formatMinorCurrency(
  amountMinor: number | bigint,
  currency = "NGN",
) {
  let formatter = currencyFormatters.get(currency);

  if (!formatter) {
    formatter = new Intl.NumberFormat("en-NG", {
      style: "currency",
      currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    currencyFormatters.set(currency, formatter);
  }

  return formatter.format(Number(amountMinor) / 100);
}
