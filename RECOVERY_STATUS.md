# TPIOS recovery status

This package is a recovery base from the uploaded archive.

## What was verified

The uploaded archive contains 20 files and is an older state of `1ruongphong-wq/ios-dylib-lab`.

It still contains:
- `TPIOSBypass.swift`
- the older `TPIOSMenu.swift`
- the older `TPIOSBootstrap.m`
- the older `.github/workflows/build.yml`

So this archive is **not** the newest state that was reached in the previous GitHub session.

## Newer states known from the previous session

The following changes were made later in GitHub, but their exact latest file bytes cannot currently be recovered because the GitHub account is suspended:

- `TPIOSBypass.swift` was renamed to `TPIOSLocation.swift`.
- Location UI was changed to support selected/manual coordinates, altitude/address fields, saved locations, selecting/deleting saved locations, and applying the selected location.
- The working save-location state reached commit `361704a2` (`Fix saving selected location`).
- A later real-location-spoof attempt added `TPIOSLocationSpoof.m`, but the latest known GitHub build still failed at link time with an undefined `TPIOSLocationSpoofInstall` symbol. That later state should therefore not be treated as a verified working baseline.
- The workflow was later changed to compile `TPIOSLocationSpoof.m` in commit `5b88c1f`, but the subsequent build still failed at link time.

## Important

This package is intentionally labeled a **recovery base**, not a claim that it is the latest repository snapshot. No newer code has been invented or silently substituted.
