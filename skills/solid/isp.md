# I — take only what you use

Smell: fat `Job`. Stapler team adds `stapleColor()` → Cutter rebuilds, Cutter's test fakes break (backwards coupling).
```ts
interface Job {
  pageCount(): number;
  isDuplex(): boolean;          // inverter
  cutPositions(): number[];     // cutter
  staplePositions(): Point[];   // stapler
  stapleType(): StapleType;     // stapler
  // ...30 more
}
class Cutter { constructor(private job: Job) {} }
```

Fix: one small interface per client.
```ts
interface CutterJob   { cutPositions(): number[]; }
interface StaplerJob  { staplePositions(): Point[]; stapleType(): StapleType; }
interface InverterJob { isDuplex(): boolean; }
class Job implements CutterJob, StaplerJob, InverterJob {}
class Cutter { constructor(private job: CutterJob) {} }

// inline with Pick — callers still pass the full object (structural typing)
type CutterJob2 = Pick<Job, "cutPositions">;
cutAll({ cutPositions: () => [10, 20] });   // tiny fake for a test
```

Even without an `interface`:
```tsx
// props: take name, not the whole User
function Greeting({ name }: { name: string }) { return <h1>Hi, {name}</h1>; }

// params: take email, not express.Request → usable from CLI, queue worker, test
async function sendResetEmail(email: string) {}   // handler calls sendResetEmail(req.body.email)

// context: take only the parts used
async function chargeCustomer(
  ctx: Pick<AppContext, "stripe" | "logger">, customerId: string, amount: number,
) {}
await chargeCustomer({ stripe: fakeStripe, logger: silentLogger }, "cus_1", 500);
```

Imports: a huge `utils.ts` that imports DB, logger, PDF lib → split it.
