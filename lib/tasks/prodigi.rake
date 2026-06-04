namespace :prodigi do
  desc "Import the Prodigi catalog CSV into local staging rows"
  task import: :environment do
    path = ENV["PATH"] || Prodigi::CatalogCsvImporter::DEFAULT_PATH
    result = Prodigi::CatalogCsvImporter.new(path: path).call!
    puts "Prodigi catalog import complete: #{result[:processed]} rows processed, #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped."
  end

  desc "Materialize Prodigi catalog items into Stripe products/prices/shipping rates"
  task materialize: :environment do
    return unless defined?(Prodigi::StripeCatalogMaterializer)

    Prodigi::StripeCatalogMaterializer.new.call!
    puts "Prodigi Stripe materialization complete."
  end

  desc "Reconcile Prodigi records missing Stripe mappings"
  task reconcile: :environment do
    Prodigi::StripeCatalogMaterializer.new(scope: ProdigiCatalogItem.joins(:prodigi_stripe_mapping).where(prodigi_stripe_mappings: { stripe_price_id: nil })).call!
    puts "Prodigi reconciliation complete."
  end
end
