namespace :prodigi do
  desc "Import the Prodigi catalog CSV into local staging rows"
  task import: :environment do
    path = ENV["PRODIGI_PATH"].presence || Prodigi::CatalogCsvImporter::DEFAULT_PATH
    dry_run = ENV["DRY_RUN"].present?
    result = Prodigi::CatalogCsvImporter.new(path: path, dry_run: dry_run).call!
    puts "Prodigi catalog import complete#{dry_run ? ' (dry run)' : ''}: #{result[:processed]} rows processed, #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped."
  end

  desc "Materialize Prodigi catalog items into Stripe products/prices/shipping rates"
  task materialize: :environment do
    return unless defined?(Prodigi::StripeCatalogMaterializer)

    dry_run = ENV["DRY_RUN"].present?
    result = Prodigi::StripeCatalogMaterializer.new(dry_run: dry_run).call!
    puts "Prodigi Stripe materialization complete#{dry_run ? ' (dry run)' : ''}."
    puts "Processed #{result[:processed]}, created #{result[:created]}, updated #{result[:updated]}, skipped #{result[:skipped]}."
  end

  desc "Reconcile Prodigi records missing Stripe mappings"
  task reconcile: :environment do
    dry_run = ENV["DRY_RUN"].present?
    result = Prodigi::StripeCatalogMaterializer.new(scope: ProdigiCatalogItem.joins(:prodigi_stripe_mapping).where(prodigi_stripe_mappings: { stripe_price_id: nil }), phase: "reconcile_stripe", dry_run: dry_run).call!
    puts "Prodigi reconciliation complete#{dry_run ? ' (dry run)' : ''}."
    puts "Processed #{result[:processed]}, created #{result[:created]}, updated #{result[:updated]}, skipped #{result[:skipped]}."
  end
end
