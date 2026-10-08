-- DEVELOPMENT / TEST SAMPLE DATA ONLY (M15 spec item 3). Never run in production.
-- Plays the vendor's part until the Vendor App can send quotes (M33): for
-- every open enquiry to a SAMPLE listing (ids 5c…), sends a quote; when a
-- quote is already waiting, sends a revised one instead (R3: the previous
-- becomes SUPERSEDED). Amounts are the listing's starting price + 20 %
-- (revisions 5 % lower), valid for 14 days. Creates N10 for the user, like
-- the real vendor flow will. Run with:  cd backend && npm run seed:dev-quotes
-- The whole script is one statement: the guard aborts it unless the
-- database name ends in _dev or _test.
DO $sample$
DECLARE
  e record;
  live record;
  new_id uuid;
  next_amount numeric(12,2);
  next_revision integer;
BEGIN
  IF current_database() !~ '_(dev|test)$' THEN
    RAISE EXCEPTION 'Sample quotes may only be created in a *_dev or *_test database (this is %).', current_database();
  END IF;

  FOR e IN
    SELECT q.id AS enquiry_id, q.event_vendor_id, q.event_id, q.vendor_id, q.user_id,
           l.title, l.starting_price_amount
      FROM enquiries q
      JOIN event_vendors ev ON ev.id = q.event_vendor_id
      JOIN vendor_listings l ON l.id = ev.listing_id
     WHERE q.status IN ('OPEN', 'QUOTED')
       AND l.id::text LIKE '5c000000-%'
     ORDER BY q.created_at
  LOOP
    SELECT id, amount, revision_no INTO live
      FROM quotations WHERE enquiry_id = e.enquiry_id AND status = 'SENT';
    IF FOUND THEN
      UPDATE quotations SET status = 'SUPERSEDED', updated_at = now(), version = version + 1
       WHERE id = live.id;
      next_amount := round(live.amount * 0.95, 2);
      next_revision := live.revision_no + 1;
    ELSE
      next_amount := round(GREATEST(e.starting_price_amount, 100) * 1.2, 2);
      next_revision := COALESCE(
        (SELECT max(revision_no) FROM quotations WHERE enquiry_id = e.enquiry_id), 0) + 1;
    END IF;

    new_id := gen_random_uuid();
    INSERT INTO quotations (id, enquiry_id, event_vendor_id, event_id, vendor_id,
                            amount, description, valid_until, revision_no)
    VALUES (new_id, e.enquiry_id, e.event_vendor_id, e.event_id, e.vendor_id,
            next_amount,
            '[Sample] Quote for ' || e.title || ' (revision ' || next_revision || '). Development data only.',
            current_date + 14, next_revision);

    UPDATE enquiries SET status = 'QUOTED', updated_at = now(), version = version + 1
     WHERE id = e.enquiry_id AND status = 'OPEN';
    UPDATE event_vendors SET status = 'QUOTED', status_changed_at = now(),
                             updated_at = now(), version = version + 1
     WHERE id = e.event_vendor_id AND status IN ('ENQUIRED', 'QUOTED');

    INSERT INTO notifications (id, recipient_type, recipient_user_id, audience, category, type,
                               entity_type, entity_id, title, body, push_policy)
    VALUES (gen_random_uuid(), 'USER', e.user_id, 'USER', 'BOOKING', 'QUOTATION_RECEIVED',
            'QUOTATION', new_id,
            CASE WHEN next_revision > 1 THEN 'Revised quote' ELSE 'New quote' END,
            'You received a quote for ' || e.title || '.', 'NEVER');
  END LOOP;
END
$sample$;
