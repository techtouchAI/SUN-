# Protection Engine Regression Baseline

**Baseline version:** `1.0.33+2578` (pending signed release)  
**Engine role:** Engineering Calculation & Data Sufficiency Engine  
**Out of scope:** Protection Device Sizing Engine, NEC/IEC compliance, and execution approval.

## Acceptance matrix

| Layer | Acceptance criterion | Regression coverage |
|---|---|---|
| Data sufficiency | Every result is built from an identified source and explicit unit. | `protection_regression_suite_test.dart` verifies the four result records, positive numeric values only, and trace availability. |
| Data sufficiency | Missing prerequisite produces an unavailable state, never `0`. | PV topology and DC conductor tests require `missingData` with `null` values and stated reasons. |
| Data sufficiency | No PV topology may be inferred from `Isc` and total panel count. | Adversarial input with `Isc=18.2 A` and 24 panels remains unavailable. |
| Calculation correctness | Inverter DC-bus current is `required inverter power / DC system voltage`. | Unit and integration tests assert the formula, unit `A`, and its source trace. |
| Calculation correctness | Inverter AC output current is `required inverter power / AC voltage` only in SUN's single-phase model. | Unit and integration tests assert the formula and single-phase limitation. |
| Calculation correctness | Current values are rebuilt from current state. | Load, voltage, panel and system-mode changes create a new report and change or remove prior values. |
| Safety boundary | The engine does not expose breaker ratings or cable cross-sections. | Labels and trace tests forbid breaker and `mm²` recommendations when prerequisite data or a ruleset is absent. |
| Safety boundary | The engine makes no NEC/IEC compliance claim. | Summary and trace assertions reject NEC, IEC and compliance wording. |
| Traceability | A numeric result includes source input, calculation rule, final result and validation. | Both numeric current results must contain all four trace stages. |
| Traceability | A blocked result includes its specific blocking reason. | PV topology and DC conductor records require validation traces and explicit Arabic reasons. |

## Negative and adversarial cases

The baseline deliberately tests conditions that must **not** turn into a plausible looking recommendation. Missing PV strings, `Isc` plus panel count without topology, missing cable-installation data, zero/invalid DC voltage, and a switch from an off-grid calculation to a direct-on-grid calculation are all required to remove or block the affected value. A value from a previous calculation must not be retained after its prerequisite is removed.

## Guardrails for later scope expansion

Any future work that adds PV topology, installation data or a licensed jurisdictional ruleset must retain this suite and add corresponding cases. A later ruleset may produce a protection-device or conductor recommendation only after the current data-sufficiency checks remain satisfied and the newly required inputs and rules are traceable.
