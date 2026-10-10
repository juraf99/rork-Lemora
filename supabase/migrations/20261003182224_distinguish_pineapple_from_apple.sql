-- Preserve the current normalizer and change only the two fruit clauses.
-- The fail-closed check prevents silently patching a different future body.
do $migration$
declare
  definition text := pg_get_functiondef('public.lemora_normalize_food_name(text)'::regprocedure);
  old_clause text := 'when s ~ ''(apple|pomme)'' then ''apple''';
  new_clause text :=
    'when s ~ ''(^|[^a-z])(pineapple|ananas)([^a-z]|$)'' then ''pineapple''' || E'\n    ' ||
    'when s ~ ''(^|[^a-z])(apple|apples|pomme|pommes)([^a-z]|$)'' then ''apple''';
begin
  if definition is null or position(old_clause in definition) = 0 then
    raise exception 'The food normalizer changed; inspect it before applying the pineapple fix';
  end if;
  execute replace(definition, old_clause, new_clause);
  if public.lemora_normalize_food_name('Golden pineapple') <> 'pineapple'
     or public.lemora_normalize_food_name('Bulk McIntosh apples') <> 'apple'
     or public.lemora_normalize_food_name('GINA Pineapple Juice') <> 'fruit_juice' then
    raise exception 'Fruit identity regression after normalizer update';
  end if;
end
$migration$;
