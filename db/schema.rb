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

ActiveRecord::Schema[8.0].define(version: 2026_05_04_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "carts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "status"], name: "index_carts_on_user_id_and_status", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "certificate_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cart_id", null: false
    t.uuid "certificate_id", null: false
    t.uuid "product_id", null: false
    t.uuid "stripe_price_map_id", null: false
    t.uuid "checkout_session_id"
    t.string "status", default: "pending", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_certificate_products_on_cart_id"
    t.index ["certificate_id"], name: "index_certificate_products_on_certificate_id"
    t.index ["checkout_session_id"], name: "index_certificate_products_on_checkout_session_id"
    t.index ["product_id"], name: "index_certificate_products_on_product_id"
    t.index ["stripe_price_map_id"], name: "index_certificate_products_on_stripe_price_map_id"
  end

  create_table "certificates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "data", default: {}, null: false
    t.string "template"
    t.index ["user_id"], name: "index_certificates_on_user_id"
  end

  create_table "checkout_session_certificates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "checkout_session_id", null: false
    t.uuid "certificate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certificate_id"], name: "index_checkout_session_certificates_on_certificate_id"
    t.index ["checkout_session_id"], name: "index_checkout_session_certificates_on_checkout_session_id"
  end

  create_table "checkout_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "raw"
    t.jsonb "items", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_session_id"
    t.string "status", default: "open", null: false
    t.uuid "cart_id"
    t.index ["cart_id"], name: "index_checkout_sessions_on_cart_id"
    t.index ["stripe_session_id"], name: "index_checkout_sessions_on_stripe_session_id", unique: true
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "price_cents", default: 0, null: false
    t.string "currency", default: "USD", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_product_id"
    t.index ["price_cents"], name: "index_products_on_price_cents"
    t.index ["stripe_product_id"], name: "index_products_on_stripe_product_id", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stripe_price_maps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.string "stripe_price_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_stripe_price_maps_on_product_id"
    t.index ["stripe_price_id"], name: "index_stripe_price_maps_on_stripe_price_id", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "carts", "users"
  add_foreign_key "certificate_products", "carts"
  add_foreign_key "certificate_products", "certificates"
  add_foreign_key "certificate_products", "checkout_sessions"
  add_foreign_key "certificate_products", "products"
  add_foreign_key "certificate_products", "stripe_price_maps"
  add_foreign_key "certificates", "users"
  add_foreign_key "checkout_session_certificates", "certificates"
  add_foreign_key "checkout_session_certificates", "checkout_sessions"
  add_foreign_key "checkout_sessions", "carts"
  add_foreign_key "sessions", "users"
  add_foreign_key "stripe_price_maps", "products"
end
