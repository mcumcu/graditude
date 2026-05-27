# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_27_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "affiliate_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "affiliate_invitation_id"
    t.text "audience"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.text "notes"
    t.text "promotion_method"
    t.datetime "reviewed_at"
    t.uuid "reviewed_by_id"
    t.string "status", default: "submitted", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["affiliate_invitation_id"], name: "index_affiliate_applications_on_affiliate_invitation_id"
    t.index ["reviewed_by_id"], name: "index_affiliate_applications_on_reviewed_by_id"
    t.index ["user_id"], name: "index_affiliate_applications_on_user_id", unique: true
  end

  create_table "affiliate_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.uuid "accepted_by_id"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at"
    t.uuid "invited_by_id"
    t.datetime "revoked_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_id"], name: "index_affiliate_invitations_on_accepted_by_id", unique: true
    t.index ["email_address"], name: "index_affiliate_invitations_on_email_address"
    t.index ["invited_by_id"], name: "index_affiliate_invitations_on_invited_by_id"
  end

  create_table "carts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "status"], name: "index_carts_on_user_id_and_status", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "certificate_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cart_id", null: false
    t.uuid "certificate_id", null: false
    t.uuid "checkout_session_id"
    t.datetime "created_at", null: false
    t.uuid "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_price_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_certificate_products_on_cart_id"
    t.index ["certificate_id"], name: "index_certificate_products_on_certificate_id"
    t.index ["checkout_session_id"], name: "index_certificate_products_on_checkout_session_id"
    t.index ["product_id"], name: "index_certificate_products_on_product_id"
    t.index ["stripe_price_id"], name: "index_certificate_products_on_stripe_price_id"
  end

  create_table "certificates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.string "template"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_certificates_on_user_id"
  end

  create_table "checkout_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cart_id"
    t.datetime "created_at", null: false
    t.jsonb "items", default: [], array: true
    t.jsonb "raw"
    t.string "shipping_currency"
    t.jsonb "shipping_details", default: {}, null: false
    t.integer "shipping_total_cents"
    t.string "status", default: "open", null: false
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_checkout_sessions_on_cart_id"
    t.index ["shipping_total_cents"], name: "index_checkout_sessions_on_shipping_total_cents"
    t.index ["stripe_session_id"], name: "index_checkout_sessions_on_stripe_session_id", unique: true
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "checkout_session_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "raw", default: {}, null: false
    t.jsonb "shipping_address", default: {}, null: false
    t.string "status", default: "order_placed", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["checkout_session_id"], name: "index_orders_on_checkout_session_id", unique: true
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "prices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "product_id", null: false
    t.jsonb "stripe_price_cache", default: {}, null: false
    t.string "stripe_price_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_prices_on_product_id"
    t.index ["stripe_price_id"], name: "index_prices_on_stripe_price_id", unique: true
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "stripe_product_cache", default: {}, null: false
    t.string "stripe_product_id"
    t.datetime "updated_at", null: false
    t.index ["stripe_product_cache"], name: "index_products_on_stripe_product_cache", using: :gin
    t.index ["stripe_product_id"], name: "index_products_on_stripe_product_id", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shipping_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "billing_basis", null: false
    t.datetime "created_at", null: false
    t.boolean "default_rate", default: false, null: false
    t.string "product_format", null: false
    t.jsonb "stripe_shipping_rate_cache", default: {}, null: false
    t.string "stripe_shipping_rate_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_shipping_rates_on_active"
    t.index ["billing_basis"], name: "index_shipping_rates_on_billing_basis"
    t.index ["default_rate"], name: "index_shipping_rates_on_default_rate"
    t.index ["product_format"], name: "index_shipping_rates_on_product_format"
    t.index ["stripe_shipping_rate_id"], name: "index_shipping_rates_on_stripe_shipping_rate_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "affiliate_approved_at"
    t.uuid "affiliate_approved_by_id"
    t.string "affiliate_status", default: "none", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest"
    t.datetime "referred_at"
    t.uuid "referred_by_id"
    t.datetime "updated_at", null: false
    t.index ["affiliate_approved_by_id"], name: "index_users_on_affiliate_approved_by_id"
    t.index ["affiliate_status"], name: "index_users_on_affiliate_status"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["referred_by_id"], name: "index_users_on_referred_by_id"
  end

  add_foreign_key "affiliate_applications", "affiliate_invitations"
  add_foreign_key "affiliate_applications", "users"
  add_foreign_key "affiliate_applications", "users", column: "reviewed_by_id"
  add_foreign_key "affiliate_invitations", "users", column: "accepted_by_id"
  add_foreign_key "affiliate_invitations", "users", column: "invited_by_id"
  add_foreign_key "carts", "users"
  add_foreign_key "certificate_products", "carts"
  add_foreign_key "certificate_products", "certificates"
  add_foreign_key "certificate_products", "checkout_sessions"
  add_foreign_key "certificate_products", "products"
  add_foreign_key "certificates", "users"
  add_foreign_key "checkout_sessions", "carts"
  add_foreign_key "orders", "checkout_sessions"
  add_foreign_key "orders", "users"
  add_foreign_key "prices", "products"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "users", column: "affiliate_approved_by_id"
  add_foreign_key "users", "users", column: "referred_by_id"
end
