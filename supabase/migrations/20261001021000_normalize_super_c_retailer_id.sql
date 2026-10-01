-- Keep mobile preference IDs and flyer retailer IDs identical.
-- Older imports used `super_c`, while the iOS catalogue has always used `superc`.
update public.grocery_store_chains
set canonical_name = 'superc'
where country_code = 'CA'
  and lower(name) = 'super c'
  and canonical_name is distinct from 'superc';
