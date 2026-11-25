# O — plugins

Core idea: old code talks to an interface; new behaviour = new class.
```ts
interface Reader { getChar(): string | null; }
interface Writer { putChar(c: string): void; }

// closed: never edited again
function copy(from: Reader, to: Writer): void {
  let c: string | null;
  while ((c = from.getChar()) !== null) to.putChar(c);
}

// open: new devices = new classes
class KeyboardReader implements Reader { getChar() { /* ... */ } }
class PrinterWriter  implements Writer { putChar(c: string) { /* ... */ } }
class FileWriter     implements Writer { putChar(c: string) { /* ... */ } }  // added later, copy() untouched
```

Payment methods:
```ts
interface PaymentMethod { acceptPayment(total: number): Payment; }

function checkOut(receipt: Receipt, items: Item[], pm: PaymentMethod): void {
  let total = 0;
  for (const item of items) { total += item.price; receipt.addItem(item); }
  receipt.addPayment(pm.acceptPayment(total));
}

class CashPaymentMethod   implements PaymentMethod { acceptPayment(total: number) { /* ... */ } }
class CreditPaymentMethod implements PaymentMethod { acceptPayment(total: number) { /* ... */ } }
```

## Expense report refactor

Smell: one function with meal rule, names and limits all switching on `type`.
```ts
type Expense = { type: "DINNER" | "BREAKFAST" | "CAR_RENTAL"; amount: number };

function printReport(expenses: Expense[], printer: Printer): void {
  let total = 0, mealExpenses = 0;
  printer.print(`Expenses ${getDate()}\n`);
  for (const e of expenses) {
    if (e.type === "BREAKFAST" || e.type === "DINNER") mealExpenses += e.amount;  // meal rule
    let name = "TILT";
    switch (e.type) {                                                              // names
      case "DINNER": name = "Dinner"; break;
      case "BREAKFAST": name = "Breakfast"; break;
      case "CAR_RENTAL": name = "Car Rental"; break;
    }
    const over = (e.type === "DINNER" && e.amount > 5000) ||                       // limits
                 (e.type === "BREAKFAST" && e.amount > 1000) ? "X" : " ";
    printer.print(`${name}\t${e.amount}\t${over}\n`);
    total += e.amount;
  }
  printer.print(`Meal expenses ${mealExpenses}\nTotal expenses ${total}\n`);
}
```

Fix: rules move into one class per kind; names are another actor → own `ExpenseNamer`.
```ts
abstract class Expense {
  constructor(readonly amount: number) {}
  abstract isMeal(): boolean;
  abstract isOverage(): boolean;
}
class DinnerExpense extends Expense {
  isMeal() { return true; }   isOverage() { return this.amount > 5000; }
}
class BreakfastExpense extends Expense {
  isMeal() { return true; }   isOverage() { return this.amount > 1000; }
}
class CarRentalExpense extends Expense {
  isMeal() { return false; }  isOverage() { return false; }
}

class ExpenseReport {                        // totals: no switch
  total = 0;
  mealExpenses = 0;
  constructor(readonly expenses: Expense[]) {}
  totalUpExpenses(): void {
    for (const e of this.expenses) {
      if (e.isMeal()) this.mealExpenses += e.amount;
      this.total += e.amount;
    }
  }
}

interface ExpenseNamer { getName(e: Expense): string; }
class ExpenseReportNamer implements ExpenseNamer {
  getName(e: Expense): string {
    if (e instanceof DinnerExpense)    return "Dinner";
    if (e instanceof BreakfastExpense) return "Breakfast";
    if (e instanceof CarRentalExpense) return "Car Rental";
    return "TILT";
  }
}

class ExpenseReporter {                      // only printing
  private namer: ExpenseNamer = new ExpenseReportNamer();
  constructor(private report: ExpenseReport, private printer: Printer) {}
  printReport(): void {
    this.report.totalUpExpenses();
    this.printer.print(`Expenses ${getDate()}\n`);
    for (const e of this.report.expenses)
      this.printer.print(`${this.namer.getName(e)}\t${e.amount}\t${e.isOverage() ? "X" : " "}\n`);
    /* print meal + total */
  }
}
```

## React: open via props
```tsx
// smell: new icon = edit the component
function Button({ kind }: { kind: "save" | "delete" }) {
  return <button>{kind === "save" ? <SaveIcon /> : <TrashIcon />} {kind}</button>;
}

// fix: callers pass any icon and text, Button never changes
function Button({ icon, children, ...rest }:
  { icon?: ReactNode; children: ReactNode } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button {...rest}>{icon} {children}</button>;
}
```

## Node: notifiers
```ts
// smell
async function notify(user: User, msg: string, channel: "email" | "sms") {
  if (channel === "email") await sendgrid.send({ to: user.email, text: msg });
  else if (channel === "sms") await twilio.messages.create({ to: user.phone, body: msg });
}

// fix
interface Notifier { send(user: User, msg: string): Promise<void>; }
class EmailNotifier implements Notifier {
  async send(user: User, msg: string) { await sendgrid.send({ to: user.email, text: msg }); }
}
class SmsNotifier implements Notifier {
  async send(user: User, msg: string) { await twilio.messages.create({ to: user.phone, body: msg }); }
}

async function notify(user: User, msg: string, notifier: Notifier) {   // closed
  await notifier.send(user, msg);
}

// main.ts — the only place that changes when Slack is added
const notifiers: Record<string, Notifier> = {
  email: new EmailNotifier(),
  sms:   new SmsNotifier(),
};
```
