-- Migration: create_orders_if_missing
-- Safe migration to ensure `public.orders` exists and has WooCommerce fields

BEGIN;

-- Ensure pgcrypto is available for gen_random_uuid (safe to run even if extension exists)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create table if missing with minimal columns
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add WooCommerce columns only if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'woocommerce_id'
  ) THEN
    ALTER TABLE public.orders ADD COLUMN woocommerce_id TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'payment_status'
  ) THEN
    ALTER TABLE public.orders ADD COLUMN payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid','paid','partial','refunded'));
  END IF;
END
$$;

COMMIT;
