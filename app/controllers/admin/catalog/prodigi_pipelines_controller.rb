module Admin
  module Catalog
    class ProdigiPipelinesController < BaseController
      def index
        @item_count = ProdigiCatalogItem.count
        @mapping_count = ProdigiStripeMapping.count
        @last_run = ProdigiPipelineRun.order(created_at: :desc).first
      end

      def import_catalog
        result = Prodigi::CatalogCsvImporter.new(path: params[:path].presence || Prodigi::CatalogCsvImporter::DEFAULT_PATH).call!
        flash[:notice] = "Prodigi catalog import complete: #{result[:processed]} rows processed, #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped."
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def materialize_stripe
        Prodigi::StripeCatalogMaterializer.new.call!
        flash[:notice] = "Prodigi Stripe materialization complete."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi Stripe materialization failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def reconcile_stripe
        Prodigi::StripeCatalogMaterializer.new(scope: ProdigiCatalogItem.joins(:prodigi_stripe_mapping).where(prodigi_stripe_mappings: { stripe_price_id: nil }), phase: "reconcile_stripe").call!
        flash[:notice] = "Prodigi Stripe reconciliation complete."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi Stripe reconciliation failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def retry_failed
        Prodigi::StripeCatalogMaterializer.new(phase: "retry_failed").call!
        flash[:notice] = "Prodigi retry completed."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi retry failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end
    end
  end
end
