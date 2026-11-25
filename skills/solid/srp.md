# S — split by actor

Smell: one class answers to three actors.
```ts
class Employee {
  calculatePay(): number { }       // Policy
  save(): Promise<void> { }        // Architecture
  describeEmployee(): string { }   // Operations
}
```

Fix: plain data type + one module per actor + an interface only where you swap/mock (DB).
```ts
// employee/types.ts
export type EmployeeData = { id: string; name: string; hourlyRate: number; timeCards: TimeCard[] };

// payroll/calculatePay.ts           (Policy)
export function calculatePay(e: EmployeeData): number { }

// reports/describeEmployee.ts       (Operations)
export function describeEmployee(e: EmployeeData): string { }

// db/employeeRepository.ts          (Architecture)
export interface EmployeeRepository { save(e: EmployeeData): Promise<void> }
export class PostgresEmployeeRepository implements EmployeeRepository { }
```

React:
```
billing/calculateInvoiceTotals.ts  // rules (pure, unit-tested)
api/useInvoice.ts                  // data
InvoicePage.tsx                    // UI only
```

Shared helper trap: `regularHours()` used by both pay (Policy) and report (Operations). Accountants change it → report breaks. Give each actor its own copy.

4 ways to split (no perfect one): one interface (actors still share a type) · extract classes (all import `Employee`) · facade (one meeting point, easy to find) · separate interfaces (actors apart, one impl class).
