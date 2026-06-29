# Edge-case hardening — driver app

Goal: close the remaining order-lifecycle edge cases so the driver flow holds
together end to end. Builds on what earlier sessions already shipped (race-safe
accept, vendor-cancel sync, unclaimed-timeout escalation, abandon/re-broadcast,
kitchen-ready timeout, offline-while-active block).

## Already handled (no work)
- S1/S2 no-driver-online → capacity signal (`hasDeliveryCapacity`, consumed by customer app)
- S3 / S3b / S3c broadcast timeout + repeated rejects → `recordAutoRejection` + `escalateOrder`
- S4 driver cancels before pickup → `abandonDelivery` re-broadcast
- S6 kitchen-ready timeout → `_kitchenReadyTimeout` warning
- S11 accept race → Firestore transaction
- S13 vendor cancels after dispatch → `_watchActiveOrder`

## This change (all driver-side, NO prod-rules changes)
Every write rides an existing Firestore rule branch: post-pickup status
self-transitions on the assigned-driver branch, plus own-driver-doc read/write.

- **A. Live suspension (S12)** — watch own driver doc; if `isSuspended` flips
  true mid-session, force sign-out. `driver_auth_provider` + service stream.
- **B. Customer-unreachable (S8/S9)** — at the drop-off, driver flags
  `customerUnreachable` (status stays `arrivedAtCustomer`). Vendor/customer
  apps consume the flag to prompt a response.
- **C. Running late (S14)** — watchdog flags `runningLate` once a picked-up
  order passes its promised ETA + grace; notifies the driver.
- **D. Post-pickup incident (S17/S18)** — once food is in hand (can't abandon),
  driver can raise `driverIncident` + reason; alerts support/vendor without a
  status rollback.
- **E. Liveness + idle nudge (S5/S16/S20)** — periodic `lastActiveAt` heartbeat
  on the driver doc (signal for a future server/admin reaper), plus a local
  nudge if the driver sits at `toRestaurant` too long after accepting.

## Consumer note
Flags B/C/D are new signals on the order doc. The driver side is fully
functional; the vendor/customer/admin apps (separate repos) need to read these
flags to surface their side of each prompt, same pattern as `noDriversAvailable`.

## Still needs a server (out of scope here, no Cloud Functions in project)
- Hard auto-release of an order whose driver's app died (S10/S20 reaping) —
  heartbeat data is now written; the reaper itself belongs server-side.
