module Admin
  module Catalog
    class ProdigiPipelinesController < BaseController
      def index
        @item_count = ProdigiCatalogItem.count
        @mapping_count = ProdigiStripeMapping.count
        @last_run = ProdigiPipelineRun.order(created_at: :desc).first
      end

      def import_catalog
        dry_run = params[:dry_run].present?
        result = Prodigi::CatalogCsvImporter.new(path: params[:path].presence || Prodigi::CatalogCsvImporter::DEFAULT_PATH, dry_run: dry_run).call!
        flash[:notice] = "Prodigi catalog import complete#{dry_run ? ' (dry run)' : ''}: #{result[:processed]} rows processed, #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped."
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def materialize_stripe
        dry_run = params[:dry_run].present?
        result = Prodigi::StripeCatalogMaterializer.new(dry_run: dry_run).call!
        flash[:notice] = "Prodigi Stripe materialization complete#{dry_run ? ' (dry run)' : ''}. Processed #{result[:processed]}, created #{result[:created]}, updated #{result[:updated]}, skipped #{result[:skipped]}."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi Stripe materialization failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def reconcile_stripe
        dry_run = params[:dry_run].present?
        result = Prodigi::StripeCatalogMaterializer.new(scope: ProdigiCatalogItem.joins(:prodigi_stripe_mapping).where(prodigi_stripe_mappings: { stripe_price_id: nil }), phase: "reconcile_stripe", dry_run: dry_run).call!
        flash[:notice] = "Prodigi Stripe reconciliation complete#{dry_run ? ' (dry run)' : ''}. Processed #{result[:processed]}, created #{result[:created]}, updated #{result[:updated]}, skipped #{result[:skipped]}."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi Stripe reconciliation failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end

      def retry_failed
        dry_run = params[:dry_run].present?
        result = Prodigi::StripeCatalogMaterializer.new(phase: "retry_failed", dry_run: dry_run).call!
        flash[:notice] = "Prodigi retry completed#{dry_run ? ' (dry run)' : ''}. Processed #{result[:processed]}, created #{result[:created]}, updated #{result[:updated]}, skipped #{result[:skipped]}."
        redirect_to admin_catalog_prodigi_pipelines_path
      rescue StandardError => error
        flash[:alert] = "Prodigi retry failed: #{error.message}"
        redirect_to admin_catalog_prodigi_pipelines_path
      end
    end
  end
end
