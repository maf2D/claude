# D — policy owns the interface

Runtime dep = a call. Source dep = an `import`. An interface inverts the source arrow.
```ts
// a.ts
export interface MyInterface { f(): void; }
export class A {
  constructor(private myInt: MyInterface) {}
  do() { this.myInt.f(); }
}

// b.ts
import type { MyInterface } from "./a";   // B imports A's interface
export class B implements MyInterface { f() { /* details */ } }

// main.ts
new A(new B()).do();
```

Smell: policy imports detail.
```ts
// orders/placeOrder.ts
import { PostgresOrderRepo } from "../db/PostgresOrderRepo";   // policy → detail
export async function placeOrder(cart: Cart) {
  await new PostgresOrderRepo().save(createOrder(cart));
}
```

Fix:
```ts
// orders/OrderRepo.ts        (policy side owns it)
export interface OrderRepo { save(order: Order): Promise<void>; }

// orders/placeOrder.ts
import type { OrderRepo } from "./OrderRepo";
export function makePlaceOrder(repo: OrderRepo) {
  return async (cart: Cart) => { await repo.save(createOrder(cart)); };
}

// db/PostgresOrderRepo.ts    (detail → policy)
import type { OrderRepo } from "../orders/OrderRepo";
export class PostgresOrderRepo implements OrderRepo { /* SQL */ }

// main.ts — the only place that knows both
const placeOrder = makePlaceOrder(new PostgresOrderRepo());
```

Two ports (refund with DB + Stripe):
```ts
// orders/ports.ts
export interface OrderRepo      { findById(id: string): Promise<Order>; }
export interface PaymentGateway { refund(paymentId: string): Promise<void>; }

// orders/refundOrder.ts
import type { OrderRepo, PaymentGateway } from "./ports";
export function makeRefundOrder(orders: OrderRepo, payments: PaymentGateway) {
  return async (orderId: string) => {
    const order = await orders.findById(orderId);
    if (order.status !== "PAID") throw new Error("Only paid orders");
    await payments.refund(order.paymentId);
  };
}

// infra/StripePaymentGateway.ts
import type { PaymentGateway } from "../orders/ports";
export class StripePaymentGateway implements PaymentGateway {
  async refund(paymentId: string) { await stripe.refunds.create({ payment_intent: paymentId }); }
}

// main.ts
const refundOrder = makeRefundOrder(new PostgresOrderRepo(), new StripePaymentGateway());
```

React: API behind an interface in context.
```tsx
// orders/OrdersApi.ts
export interface OrdersApi { list(): Promise<Order[]>; }
export const OrdersApiContext = createContext<OrdersApi | null>(null);

// orders/useOrders.ts
export function useOrders() {
  const api = useContext(OrdersApiContext)!;
  return useQuery({ queryKey: ["orders"], queryFn: () => api.list() });
}

// App.tsx: <OrdersApiContext.Provider value={httpOrdersApi}>
// tests:   <OrdersApiContext.Provider value={{ list: async () => [fakeOrder] }}>
```
