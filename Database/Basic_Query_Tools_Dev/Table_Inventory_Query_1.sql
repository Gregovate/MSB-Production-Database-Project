SELECT
    a.attnum                                   AS column_order,
    a.attname                                  AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull                               AS not_null,
    pg_get_expr(ad.adbin, ad.adrelid)          AS default_value
FROM pg_attribute a
LEFT JOIN pg_attrdef ad
       ON a.attrelid = ad.adrelid
      AND a.attnum = ad.adnum
WHERE a.attrelid = 'ref.display'::regclass
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;