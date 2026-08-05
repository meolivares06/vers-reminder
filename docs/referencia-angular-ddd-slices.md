# Informe de Arquitectura — store-ddd-slices (Angular)

**Stack**: Angular 22+, TypeScript, Signals, ngrx/signals, Vitest  
**Arquitectura**: DDD + Vertical Slices + Screaming Architecture  
**Fecha**: 2026-08-04  
**Origen**: Análisis para referencia cruzada con vers-reminder (Flutter)

---

## Estructura general

```
src/app/
├── products/       ← Catálogo (completo, 3 capas)
├── cart/           ← Carrito (completo, 3 capas + event bus)
├── checkout/       ← TODO (vacío)
├── layout/         ← Shell visual
├── shared/         ← Domain compartido (Price VO, eventos)
└── app/            ← Root app
```

Cada slice (`products/`, `cart/`) es autónomo — tiene su propio `domain/`, `infrastructure/`, `application/`. No hay carpetas compartidas de `components/`, `services/` o `models/`.

---

## Capas por slice

| Capa | Responsabilidad | Angular | Ejemplo |
|---|---|---|---|
| `domain/` | Entidades, Value Objects, reglas de negocio | No | `Product`, `Cart`, `Price` |
| `infrastructure/` | HTTP, localStorage, DTOs, mappers | Sí | `ProductHttp`, `CartLocalStorageService` |
| `application/` | Stores (signals), orquestación, UI | Sí | `ProductStore`, `CartService` |

### Domain — Zero Angular

- Constructor `private` + `static create()` con validación
- Value Objects inmutables (`Price.applyDiscount()` devuelve nueva instancia)
- Aggregate Root: colecciones privadas expuestas como `readonly`
- Zero imports de Angular, zero frameworks

### Infrastructure — DTOs + Mappers

- DTOs con prefijo `Api*`: `ApiProduct`, `ApiProductResponse`
- Mappers explícitos: funciones puras `mapToProduct(api: ApiProduct): Product`
- Implementan interfaces del application layer

### Application — Signals + DI

- Estado vía `signal()`, `computed()` — nunca RxJS para estado
- Inyección por `InjectionToken` (`PRODUCT_REPOSITORY_TOKEN`)
- Componentes dumb: solo `input()` / `output()`, sin inyección
- Componentes smart: inyectan store, delegan en dumb components

---

## Hallazgos

| # | Severidad | Hallazgo |
|---|---|---|
| 1 | Alto | **18/20 tests rotos** — `describe is not defined`. Los specs usan Jasmine pero el proyecto usa Vitest. Falta `globals: true` en `vitest.config.ts`. Solo pasan 2 tests (funciones puras). |
| 2 | Medio | **Doble store en products** — `ProductStore` (@Service) y `productsStore` (ngrx signalStore) conviven inyectándose mutuamente. Una sobra. |
| 3 | Medio | **`Price` en `shared/` vs `ARCHITECTURE.md`** — El doc dice que está en `products/domain/`, pero está en `shared/domain/`. El doc está desactualizado. |
| 4 | Bajo | **`applyDiscountToAll()` comentado** en `ProductStore` — código muerto. |
| 5 | Bajo | **`Checkout` vacío** — solo un `TODO.md`, sin implementar. |
| 6 | Positivo | **Domain bien aislado** — `Product.create()` valida, `Cart` Aggregate Root, `Price` Value Object inmutable. |
| 7 | Positivo | **DIP respetado** — Stores inyectan tokens, nunca clases concretas. |
| 8 | Positivo | **Event bus en cart** — `EventBusService` + `AddToCartRequestedEvent` para comunicación desacoplada. |

---

## Tests

```
20 spec files
 2 passing  (product-sort-criteria, product-sort-query) — funciones puras
18 failing — "describe is not defined" (Vitest sin globals)
 8 assertions (solo en los 2 que pasan)
```

**Causa raíz**: `vitest.config.ts` no tiene `globals: true`. Los specs usan `describe`/`it` sin importarlos.

**Fix**: Agregar `globals: true` en `vitest.config.ts` o migrar a imports explícitos.

---

## Lo que está bien

- Separación de capas estricta (domain / infrastructure / application)
- Factory Method + validación en entidades
- DTOs con prefijo `Api*` y mappers explícitos
- Inyección por `InjectionToken` (DIP)
- Uso de Signals (`signal()`, `computed()`) en stores
- Event Bus para comunicación entre slices
- Standalone components, `@if/@for` control flow (Angular 22+)

## Lo que hay que arreglar

1. **Urgente**: Configurar `vitest` con `globals: true` para que los 18 tests pasen
2. **Recomendado**: Unificar el doble store de products (elegir `@Service()` o `signalStore`)
3. **Cosmético**: Actualizar `ARCHITECTURE.md` para reflejar que `Price` está en `shared/domain/`
