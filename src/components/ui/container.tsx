export function Container({
  children,
  className = "",
}: Readonly<{
  children: React.ReactNode;
  className?: string;
}>) {
  return (
    <div className={`mx-auto w-full max-w-[1600px] ${className}`}>
      {children}
    </div>
  );
}
