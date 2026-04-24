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
