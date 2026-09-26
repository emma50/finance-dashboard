export function PageHeading({
  eyebrow,
  title,
  description,
}: Readonly<{
  eyebrow?: string;
  title: string;
  description?: string;
}>) {
  return (
    <header className="space-y-2">
      {eyebrow ? (
        <p className="text-muted text-sm font-medium">{eyebrow}</p>
      ) : null}
      <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
      {description ? (
        <p className="text-muted max-w-3xl text-sm leading-6">{description}</p>
      ) : null}
    </header>
  );
}
