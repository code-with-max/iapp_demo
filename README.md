# Godot Google Play IAPP Demo

Demonstration application for the open-source Godot Engine plugin `godot-google-play-iapp`.

This app is designed for developers, QA engineers, and Godot creators who want to test and verify Google Play Billing integration (Google Play Billing Library) in a real-world Android environment using Godot 4.3+.

## What This Demo Showcases

### Consumable In-App Purchases (InApp Products)

- Instant consumption of virtual goods (e.g., Gold Coins packs).
- Testing purchase flows, offers, and tokens.

### Non-Consumable In-App Purchases

- Permanent unlocks (e.g., Pro Features Pack, Starter Kits).
- Automatic acknowledgement handling to prevent 3-day refunds.

### Subscriptions (Multi-Plan Support)

- Monthly auto-renewing base plans (e.g., VIP Pass, No Ads).
- Acknowledgment flow and subscription state monitoring.

### Advanced Billing Features

- Querying product details (prices, formatted strings, offer tokens).
- Handling order states: `PURCHASED`, `CANCELLED`, `PENDING`.
- Real-time signal tracking for errors, state updates, and logs.

## Important Note

This is a test sandbox environment application. No real physical goods are delivered, and transactions follow standard Google Play internal testing/license testing procedures.

## Open-Source Plugin Details

- **Plugin name:** AndroidIAPP / `godot-google-play-iapp`
- **Target version:** Godot 4.3+ (supports Godot 4.6+)
- **Billing Library:** Google Play Billing 9.1.0+
- **Repository:** <https://github.com/code-with-max/godot-google-play-iapp>

Use this demo app to quickly verify your Play Console SKU setups, test purchase callbacks, and ensure your Godot Android game is ready for production monetization.