module Admin
  module Catalog
    class ProductsController < BaseController
      before_action :set_product, only: %i[edit update destroy]

      def index
        @products = Product.where.not(stripe_product_id: nil).order(created_at: :desc)
      end

      def new
        @form = Admin::CatalogProductForm.new(active: true, currency: "usd")
      end

      def create
        @form = Admin::CatalogProductForm.new(form_params)

        if @form.save
          ::Catalog::Broadcasts.product_created(@form.product)
          redirect_to admin_catalog_products_path, notice: "Product created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @form = Admin::CatalogProductForm.from_product(@product)
      end

      def preview
        preview_product = ::Catalog::PreviewProduct.from_input(preview_params, fallback_product: find_preview_fallback)
        template_name = preview_product.certificate_template_names.first.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")

        render partial: "admin/catalog/products/preview",
               locals: {
                 product: preview_product,
                 template_name: template_name
               }
      end

      def update
        @form = Admin::CatalogProductForm.new(form_params.merge(product: @product))

        if @form.save
          ::Catalog::Broadcasts.product_updated(@product)
          redirect_to edit_admin_catalog_product_path(@product), notice: "Product updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @form = Admin::CatalogProductForm.new(product: @product)

        if @form.archive
          ::Catalog::Broadcasts.product_updated(@product)
          redirect_to admin_catalog_products_path, notice: "Product archived."
        else
          redirect_to edit_admin_catalog_product_path(@product), alert: @form.errors.full_messages.to_sentence
        end
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end

      def form_params
        params.require(:catalog_product).permit(
          :name,
          :eyebrow,
          :tagline,
          :description,
          :short_description,
          :detail_intro,
          :attributes_text,
          :marketing_features_text,
          :certificate_templates_text,
          :images_text,
          :variant_format,
          :active,
          :tax_code,
          :price_amount,
          :currency,
          :extra_metadata_json,
          :extra_product_json
        )
      end

      def preview_params
        params.require(:catalog_product).permit(
          :name,
          :eyebrow,
          :tagline,
          :description,
          :short_description,
          :detail_intro,
          :attributes_text,
          :marketing_features_text,
          :certificate_templates_text,
          :images_text,
          :variant_format,
          :active,
          :tax_code,
          :price_amount,
          :currency
        )
      end

      def find_preview_fallback
        return unless params[:id].present?

        Product.find_by(id: params[:id])
      end
    end
  end
end
