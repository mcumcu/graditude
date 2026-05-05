# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Local engine development and reload support

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Local engine development

This app uses a local engine from `engines/graditude_factory` via the Gemfile.

For development, the engine is configured to reload Ruby changes from:

```ruby
Rails.root.join("engines/graditude_factory/lib")
```

This keeps changes in `graditude_factory` visible without restarting the Rails server.

## Generate a Boulder preview PNG

To render the Boulder certificate preview and overwrite `app/assets/images/boulder.png`, run:

```bash
bin/rails runner 'require "fileutils"; ctrl = CertificatesController.new; params = ctrl.default_certificate_params.merge("presented_on" => "May 15, 2026"); doc = ctrl.make_certificate_document("boulder", params); pdf = ctrl.temp_pdf_path("boulder_preview").to_s; doc.render_file(pdf); png = Rails.root.join("app","assets","images","boulder.png").to_s; FileUtils.rm_f(png); ctrl.render_certificate_png(pdf, png); puts png'
```

## Stripe Checkout

This application supports a Stripe Checkout integration using Rails controllers and Stimulus.

Client-side Stripe JS is loaded through Importmaps:

```bash
bin/importmap pin @stripe/stripe-js
```

A Stimulus controller can import the wrapper and initialize Stripe with `loadStripe`:

```js
import { Controller } from "@hotwired/stimulus"
import { loadStripe } from "@stripe/stripe-js"

export default class extends Controller {
  async connect() {
    const stripe = await loadStripe("your_publishable_key")
    // Initialize Elements or Checkout here
  }
}
```

Stripe.js is loaded from `js.stripe.com` via the Stripe JS wrapper. Do not bundle the raw `stripe.js` file into our own assets or host it ourselves.

This integration also forwards dynamic per-item display data to Checkout using `line_items.price_data.product_data.*`, so item name, description, and image can be overridden at runtime while Stripe price behavior remains unchanged.

If you use a Content Security Policy (CSP), whitelist:

* `https://js.stripe.com`
* `https://api.stripe.com`

Required Stripe-related environment variables:

* `STRIPE_KEY` — Stripe secret key stored on the server only.
* `STRIPE_KEY_PUB` — Stripe publishable key exposed to the browser.
* `STRIPE_WEBHOOK_SECRET` — Stripe webhook signing secret used to verify incoming webhook payloads.

Make sure `STRIPE_KEY` and `STRIPE_WEBHOOK_SECRET` are kept out of source control; use sandbox values for local development. Add these keys to your `.env.local`.

Do not commit the Stripe secrets to source control!
For Fly.io production, set all Stripe secrets with `fly secrets set STRIPE_KEY=... STRIPE_KEY_PUB=... STRIPE_WEBHOOK_SECRET=...`; do not commit them in `fly.toml`.

Stripe webhook endpoint:

* `POST /stripe/webhook` — receives Stripe event notifications
* The app verifies `Stripe-Signature` using `ENV["STRIPE_WEBHOOK_SECRET"]`
* Invalid signatures are intentionally returned as `200 OK` so Stripe continues delivery

Supported Stripe webhook event types:

* `checkout.session.completed`
* `checkout.session.async_payment_succeeded`
* `checkout.session.expired`
* `checkout.session.async_payment_failed`
* `product.created`
* `product.updated`
* `product.deleted`

Routes:

* `GET /checkout` — renders the checkout page.
* `POST /checkout` — creates a Stripe Checkout Session.
* `GET /checkout/success` — success landing page after payment.
* `GET /checkout/cancel` — cancellation page when the customer returns.

To run the checkout controller tests:

```bash
bundle exec rails test test/controllers/checkout_sessions_controller_test.rb
```

