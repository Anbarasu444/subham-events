-- DEVELOPMENT / TEST SAMPLE DATA ONLY (M12 spec item 2). Never run in production.
-- Fake vendors and listings so vendor discovery can be tried before the
-- Vendor App (M26-M28) and admin approval (M40+) exist. Every row is marked:
-- users.firebase_uid 'sample-vendor-N' and @example.invalid emails (no
-- sign-in possible), descriptions start with "[Sample]", ids start with
-- 5a/5b/5c. Rows 19-20 are deliberately hidden from discovery (a draft
-- listing; a suspended vendor). Idempotent (fixed ids, ON CONFLICT DO NOTHING).
-- Run with:  cd backend && npm run seed:dev-samples
-- The whole script is one statement: the guard aborts it unless the
-- database name ends in _dev or _test.
DO $sample$
BEGIN
  IF current_database() !~ '_(dev|test)$' THEN
    RAISE EXCEPTION 'Sample vendors may only be loaded into a *_dev or *_test database (this is %).', current_database();
  END IF;

  INSERT INTO users (id, firebase_uid, display_name, email)
  VALUES
    ('5a000000-0000-4000-8000-000000000001', 'sample-vendor-1', 'Lotus Grand Mahal', 'sample-vendor-1@example.invalid'),
    ('5a000000-0000-4000-8000-000000000002', 'sample-vendor-2', 'Annapoorna Caterers', 'sample-vendor-2@example.invalid'),
    ('5a000000-0000-4000-8000-000000000003', 'sample-vendor-3', 'Marigold Decor Studio', 'sample-vendor-3@example.invalid'),
    ('5a000000-0000-4000-8000-000000000004', 'sample-vendor-4', 'Candid Frames', 'sample-vendor-4@example.invalid'),
    ('5a000000-0000-4000-8000-000000000005', 'sample-vendor-5', 'Reel Moments Films', 'sample-vendor-5@example.invalid'),
    ('5a000000-0000-4000-8000-000000000006', 'sample-vendor-6', 'Glow by Divya', 'sample-vendor-6@example.invalid'),
    ('5a000000-0000-4000-8000-000000000007', 'sample-vendor-7', 'Beat Street DJs', 'sample-vendor-7@example.invalid'),
    ('5a000000-0000-4000-8000-000000000008', 'sample-vendor-8', 'Kolam Prints', 'sample-vendor-8@example.invalid'),
    ('5a000000-0000-4000-8000-000000000009', 'sample-vendor-9', 'Royal Ride Cars', 'sample-vendor-9@example.invalid'),
    ('5a000000-0000-4000-8000-000000000010', 'sample-vendor-10', 'Thambulam Gifts', 'sample-vendor-10@example.invalid'),
    ('5a000000-0000-4000-8000-000000000011', 'sample-vendor-11', 'Sri Vedic Services', 'sample-vendor-11@example.invalid'),
    ('5a000000-0000-4000-8000-000000000012', 'sample-vendor-12', 'Kovai Kalyana Mandapam', 'sample-vendor-12@example.invalid'),
    ('5a000000-0000-4000-8000-000000000013', 'sample-vendor-13', 'Kongu Virundhu Caterers', 'sample-vendor-13@example.invalid'),
    ('5a000000-0000-4000-8000-000000000014', 'sample-vendor-14', 'Western Ghats Studio', 'sample-vendor-14@example.invalid'),
    ('5a000000-0000-4000-8000-000000000015', 'sample-vendor-15', 'Meenakshi Decorators', 'sample-vendor-15@example.invalid'),
    ('5a000000-0000-4000-8000-000000000016', 'sample-vendor-16', 'Madurai Mess Caterers', 'sample-vendor-16@example.invalid'),
    ('5a000000-0000-4000-8000-000000000017', 'sample-vendor-17', 'Garden City Events', 'sample-vendor-17@example.invalid'),
    ('5a000000-0000-4000-8000-000000000018', 'sample-vendor-18', 'Hosur Lens Works', 'sample-vendor-18@example.invalid'),
    ('5a000000-0000-4000-8000-000000000019', 'sample-vendor-19', 'Draft Decor Co', 'sample-vendor-19@example.invalid'),
    ('5a000000-0000-4000-8000-000000000020', 'sample-vendor-20', 'Paused Pixels', 'sample-vendor-20@example.invalid')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO vendors (id, user_id, business_name, description, city, service_areas, status)
  VALUES
    ('5b000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001', 'Lotus Grand Mahal', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Tambaram','Velachery']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000002', 'Annapoorna Caterers', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Kanchipuram']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000003', '5a000000-0000-4000-8000-000000000003', 'Marigold Decor Studio', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000004', '5a000000-0000-4000-8000-000000000004', 'Candid Frames', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Pondicherry','Vellore']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000005', '5a000000-0000-4000-8000-000000000005', 'Reel Moments Films', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000006', 'Glow by Divya', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Tambaram']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000007', '5a000000-0000-4000-8000-000000000007', 'Beat Street DJs', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000008', '5a000000-0000-4000-8000-000000000008', 'Kolam Prints', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000009', '5a000000-0000-4000-8000-000000000009', 'Royal Ride Cars', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Chengalpattu']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000010', '5a000000-0000-4000-8000-000000000010', 'Thambulam Gifts', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000011', '5a000000-0000-4000-8000-000000000011', 'Sri Vedic Services', '[Sample] Development data, not a real business.', 'Chennai', ARRAY['Kanchipuram','Tiruvallur']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000012', '5a000000-0000-4000-8000-000000000012', 'Kovai Kalyana Mandapam', '[Sample] Development data, not a real business.', 'Coimbatore', ARRAY['Tiruppur']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000013', '5a000000-0000-4000-8000-000000000013', 'Kongu Virundhu Caterers', '[Sample] Development data, not a real business.', 'Coimbatore', ARRAY['Erode','Tiruppur']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000014', '5a000000-0000-4000-8000-000000000014', 'Western Ghats Studio', '[Sample] Development data, not a real business.', 'Coimbatore', ARRAY['Ooty']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000015', '5a000000-0000-4000-8000-000000000015', 'Meenakshi Decorators', '[Sample] Development data, not a real business.', 'Madurai', ARRAY['Dindigul']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000016', '5a000000-0000-4000-8000-000000000016', 'Madurai Mess Caterers', '[Sample] Development data, not a real business.', 'Madurai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000017', '5a000000-0000-4000-8000-000000000017', 'Garden City Events', '[Sample] Development data, not a real business.', 'Bengaluru', ARRAY['Hosur']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000018', '5a000000-0000-4000-8000-000000000018', 'Hosur Lens Works', '[Sample] Development data, not a real business.', 'Bengaluru', ARRAY['Hosur','Krishnagiri']::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000019', '5a000000-0000-4000-8000-000000000019', 'Draft Decor Co', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'ACTIVE'),
    ('5b000000-0000-4000-8000-000000000020', '5a000000-0000-4000-8000-000000000020', 'Paused Pixels', '[Sample] Development data, not a real business.', 'Chennai', '{}'::text[], 'SUSPENDED')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO vendor_listings (id, vendor_id, category_id, title, description, starting_price_amount, city, service_areas, status, approved_at)
  SELECT v.id, v.vendor_id, c.id, v.title, v.description, v.price, v.city, v.areas, v.status, v.approved_at
  FROM (VALUES
    ('5c000000-0000-4000-8000-000000000001'::uuid, '5b000000-0000-4000-8000-000000000001'::uuid, 'venue', 'Lotus Grand Mahal — AC wedding hall for 800', '[Sample] Lotus Grand Mahal — AC wedding hall for 800. Development data only.', 150000.00::numeric, 'Chennai', ARRAY['Tambaram','Velachery']::text[], 'APPROVED', now() - interval '1 days'),
    ('5c000000-0000-4000-8000-000000000002'::uuid, '5b000000-0000-4000-8000-000000000002'::uuid, 'catering', 'Traditional South Indian wedding feast', '[Sample] Traditional South Indian wedding feast. Development data only.', 450.00::numeric, 'Chennai', ARRAY['Kanchipuram']::text[], 'APPROVED', now() - interval '2 days'),
    ('5c000000-0000-4000-8000-000000000003'::uuid, '5b000000-0000-4000-8000-000000000003'::uuid, 'decoration', 'Floral stage and mandap decoration', '[Sample] Floral stage and mandap decoration. Development data only.', 35000.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '3 days'),
    ('5c000000-0000-4000-8000-000000000004'::uuid, '5b000000-0000-4000-8000-000000000004'::uuid, 'photography', 'Candid wedding photography', '[Sample] Candid wedding photography. Development data only.', 25000.00::numeric, 'Chennai', ARRAY['Pondicherry','Vellore']::text[], 'APPROVED', now() - interval '4 days'),
    ('5c000000-0000-4000-8000-000000000005'::uuid, '5b000000-0000-4000-8000-000000000005'::uuid, 'videography', 'Cinematic wedding films', '[Sample] Cinematic wedding films. Development data only.', 40000.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '5 days'),
    ('5c000000-0000-4000-8000-000000000006'::uuid, '5b000000-0000-4000-8000-000000000006'::uuid, 'makeup-mehendi', 'Bridal makeup and mehendi', '[Sample] Bridal makeup and mehendi. Development data only.', 18000.00::numeric, 'Chennai', ARRAY['Tambaram']::text[], 'APPROVED', now() - interval '6 days'),
    ('5c000000-0000-4000-8000-000000000007'::uuid, '5b000000-0000-4000-8000-000000000007'::uuid, 'music-dj', 'DJ and sound for sangeet and reception', '[Sample] DJ and sound for sangeet and reception. Development data only.', 22000.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '7 days'),
    ('5c000000-0000-4000-8000-000000000008'::uuid, '5b000000-0000-4000-8000-000000000008'::uuid, 'invitations-printing', 'Printed and digital wedding invitations', '[Sample] Printed and digital wedding invitations. Development data only.', 3500.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '8 days'),
    ('5c000000-0000-4000-8000-000000000009'::uuid, '5b000000-0000-4000-8000-000000000009'::uuid, 'transport', 'Decorated wedding cars', '[Sample] Decorated wedding cars. Development data only.', 6000.00::numeric, 'Chennai', ARRAY['Chengalpattu']::text[], 'APPROVED', now() - interval '9 days'),
    ('5c000000-0000-4000-8000-000000000010'::uuid, '5b000000-0000-4000-8000-000000000010'::uuid, 'gifts-return-gifts', 'Return gift hampers', '[Sample] Return gift hampers. Development data only.', 150.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '10 days'),
    ('5c000000-0000-4000-8000-000000000011'::uuid, '5b000000-0000-4000-8000-000000000011'::uuid, 'priest-rituals', 'Priest services for weddings and poojas', '[Sample] Priest services for weddings and poojas. Development data only.', 11000.00::numeric, 'Chennai', ARRAY['Kanchipuram','Tiruvallur']::text[], 'APPROVED', now() - interval '11 days'),
    ('5c000000-0000-4000-8000-000000000012'::uuid, '5b000000-0000-4000-8000-000000000012'::uuid, 'venue', 'Kalyana mandapam with dining hall', '[Sample] Kalyana mandapam with dining hall. Development data only.', 90000.00::numeric, 'Coimbatore', ARRAY['Tiruppur']::text[], 'APPROVED', now() - interval '12 days'),
    ('5c000000-0000-4000-8000-000000000013'::uuid, '5b000000-0000-4000-8000-000000000013'::uuid, 'catering', 'Kongu-style wedding catering', '[Sample] Kongu-style wedding catering. Development data only.', 380.00::numeric, 'Coimbatore', ARRAY['Erode','Tiruppur']::text[], 'APPROVED', now() - interval '13 days'),
    ('5c000000-0000-4000-8000-000000000014'::uuid, '5b000000-0000-4000-8000-000000000014'::uuid, 'photography', 'Wedding and pre-wedding shoots', '[Sample] Wedding and pre-wedding shoots. Development data only.', 30000.00::numeric, 'Coimbatore', ARRAY['Ooty']::text[], 'APPROVED', now() - interval '14 days'),
    ('5c000000-0000-4000-8000-000000000015'::uuid, '5b000000-0000-4000-8000-000000000015'::uuid, 'decoration', 'Temple-style decoration', '[Sample] Temple-style decoration. Development data only.', 28000.00::numeric, 'Madurai', ARRAY['Dindigul']::text[], 'APPROVED', now() - interval '15 days'),
    ('5c000000-0000-4000-8000-000000000016'::uuid, '5b000000-0000-4000-8000-000000000016'::uuid, 'catering', 'Madurai special wedding meals', '[Sample] Madurai special wedding meals. Development data only.', 320.00::numeric, 'Madurai', '{}'::text[], 'APPROVED', now() - interval '16 days'),
    ('5c000000-0000-4000-8000-000000000017'::uuid, '5b000000-0000-4000-8000-000000000017'::uuid, 'venue', 'Garden lawn for receptions', '[Sample] Garden lawn for receptions. Development data only.', 200000.00::numeric, 'Bengaluru', ARRAY['Hosur']::text[], 'APPROVED', now() - interval '17 days'),
    ('5c000000-0000-4000-8000-000000000018'::uuid, '5b000000-0000-4000-8000-000000000018'::uuid, 'photography', 'Traditional and candid photography', '[Sample] Traditional and candid photography. Development data only.', 20000.00::numeric, 'Bengaluru', ARRAY['Hosur','Krishnagiri']::text[], 'APPROVED', now() - interval '18 days'),
    ('5c000000-0000-4000-8000-000000000019'::uuid, '5b000000-0000-4000-8000-000000000019'::uuid, 'decoration', 'Draft listing, not yet submitted', '[Sample] Draft listing, not yet submitted. Development data only.', 10000.00::numeric, 'Chennai', '{}'::text[], 'DRAFT', NULL::timestamptz),
    ('5c000000-0000-4000-8000-000000000020'::uuid, '5b000000-0000-4000-8000-000000000020'::uuid, 'photography', 'Listing of a suspended vendor', '[Sample] Listing of a suspended vendor. Development data only.', 15000.00::numeric, 'Chennai', '{}'::text[], 'APPROVED', now() - interval '20 days')
  ) AS v(id, vendor_id, slug, title, description, price, city, areas, status, approved_at)
  JOIN vendor_categories c ON c.slug = v.slug
  ON CONFLICT (id) DO NOTHING;
END
$sample$;
