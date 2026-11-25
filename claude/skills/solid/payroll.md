# All together — Payroll

Find actors → data dictionary as types → every `A | B | C` becomes interface + one class per option.
```ts
// Policy: how much
interface PayType { calculatePay(period: Period): number; }
class HourlyPay implements PayType {
  private timeCards: TimeCard[] = [];
  constructor(private hourlyRate: number) {}
  addTimeCard(tc: TimeCard) { this.timeCards.push(tc); }
  calculatePay(period: Period) {
    return this.timeCards.filter(tc => period.contains(tc.date))
      .reduce((sum, tc) => sum + tc.hoursWorked * this.hourlyRate, 0);   // + overtime rules
  }
}
class SalariedPay     implements PayType { /* salary */ }
class CommissionedPay implements PayType { /* basePay + sales receipts × rate */ }

// Policy: when
interface PaySchedule {
  isPayDay(date: Date): boolean;
  payPeriodFor(payDate: Date): Period;
}
class WeeklySchedule   implements PaySchedule { /* every Friday */ }
class BiWeeklySchedule implements PaySchedule { /* every 2nd Friday */ }
class MonthlySchedule  implements PaySchedule { /* last day of month */ }

// Policy: how money is delivered
interface PayDisposition { deliver(paycheck: Paycheck): Promise<void>; }
class MailDisposition          implements PayDisposition { constructor(private address: string) {} }
class PaymasterDisposition     implements PayDisposition { }
class DirectDepositDisposition implements PayDisposition { constructor(private account: string) {} }

// Union
interface UnionMembership { calculateDeductions(period: Period): number; }
class UnionMember implements UnionMembership {
  private serviceCharges: ServiceCharge[] = [];
  constructor(private weeklyDues: number) {}
  addServiceCharge(sc: ServiceCharge) { this.serviceCharges.push(sc); }
  calculateDeductions(period: Period) { /* dues + charges in period */ }
}
class NonMember implements UnionMembership {   // Null Object: no `if (isMember)` anywhere
  calculateDeductions() { return 0; }
}

// Employee only puts the pieces together — no if/switch on kinds
class Employee {
  constructor(
    readonly id: string,
    readonly name: string,
    public payType: PayType,
    public schedule: PaySchedule,
    public disposition: PayDisposition,
    public union: UnionMembership,
  ) {}
  isPayDay(date: Date) { return this.schedule.isPayDay(date); }
  async payday(date: Date) {
    const period = this.schedule.payPeriodFor(date);
    const gross = this.payType.calculatePay(period);
    const deductions = this.union.calculateDeductions(period);
    await this.disposition.deliver({ employeeId: this.id, gross, deductions, net: gross - deductions });
  }
}
```

One use case per action, each with its own request type (plain data). Shared steps in an abstract base (template method).
```ts
type AddEmployeeRequest         = { name: string; payDisposition: PayDispositionData; unionMembership?: { weeklyDues: number } };
type AddHourlyEmployeeRequest   = AddEmployeeRequest & { hourlyRate: number };
type AddCommissionedEmpRequest  = AddEmployeeRequest & { basePay: number; commissionRate: number };
type AddSalariedEmployeeRequest = AddEmployeeRequest & { salary: number };
type SetUnionMembershipRequest  = { employeeId: string; weeklyDues: number };

interface UseCase<R> { execute(req: R): Promise<void>; }

abstract class AddEmployeeUseCase<R extends AddEmployeeRequest> implements UseCase<R> {
  constructor(private repo: EmployeeRepo, private setUnion: UseCase<SetUnionMembershipRequest>) {}
  async execute(req: R) {
    const e = new Employee(newId(), req.name, this.makePayType(req), this.makeSchedule(),
                           makeDisposition(req.payDisposition), new NonMember());
    await this.repo.save(e);
    if (req.unionMembership)                                   // union = another actor → another use case
      await this.setUnion.execute({ employeeId: e.id, ...req.unionMembership });
  }
  protected abstract makePayType(req: R): PayType;
  protected abstract makeSchedule(): PaySchedule;
}

class AddHourlyEmployeeUseCase extends AddEmployeeUseCase<AddHourlyEmployeeRequest> {
  protected makePayType(r: AddHourlyEmployeeRequest) { return new HourlyPay(r.hourlyRate); }
  protected makeSchedule() { return new WeeklySchedule(); }
}
```

Controller knows interfaces only; the factory is the one place that lists all kinds.
```ts
interface RequestBuilder { build(payType: string, body: unknown): AddEmployeeRequest; }
interface UseCaseFactory { make(payType: string): UseCase<AddEmployeeRequest>; }

class AddEmployeeController {
  constructor(private builder: RequestBuilder, private factory: UseCaseFactory) {}
  async handle(httpReq: { body: { payType: string } }) {
    const { payType } = httpReq.body;
    const req = this.builder.build(payType, httpReq.body);   // validates + makes the request DS
    await this.factory.make(payType).execute(req);           // doesn't know WHICH use case
  }
}

class UseCaseFactoryImpl implements UseCaseFactory {
  constructor(private repo: EmployeeRepo, private setUnion: UseCase<SetUnionMembershipRequest>) {}
  make(payType: string) {
    switch (payType) {
      case "hourly":       return new AddHourlyEmployeeUseCase(this.repo, this.setUnion);
      case "salaried":     return new AddSalariedEmployeeUseCase(this.repo, this.setUnion);
      case "commissioned": return new AddCommissionedEmployeeUseCase(this.repo, this.setUnion);
      default: throw new Error(`Unknown pay type: ${payType}`);
    }
  }
}
```

No perfect design. Build for today's real variants, not a guessed future.
