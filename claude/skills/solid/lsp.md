# L — keep promises

```ts
// Square is a rectangle in math, not in code (setters break).
// Share only what both can promise:
interface Shape { area(): number; }
class Rectangle implements Shape {
  constructor(readonly width: number, readonly height: number) {}
  area() { return this.width * this.height; }
}
class Square implements Shape {
  constructor(readonly size: number) {}
  area() { return this.size ** 2; }
}

// Array params: Dog[] passes as Animal[] and lets a Cat in (runtime TypeError, tsc --strict is silent).
function feedAll(animals: readonly Animal[]) {}
```

Smells: `throw new Error("not supported")` in an implemented method · `instanceof` / `type ===` in code that should not care · a wrapper component that drops native props · a test fake that behaves differently from the real thing.
