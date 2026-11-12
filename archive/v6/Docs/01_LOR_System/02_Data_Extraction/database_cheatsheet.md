# MSB Database Cheat Sheet

## SQL Queries

Here are some useful SQLite queries you can run against `lor_output_v6.db`.
# MSB Database Cheat Sheet

## SQL Queries

Here are some useful SQLite queries you can run against `lor_output_v6.db`.

### List all unique controllers and the networks they are used on
```sql
SELECT *
FROM controller_networks_v6;
```
👉 Already sorted by `Network, Controller`.

### Props only (all previews, no DMX/None)
```sql
SELECT *
FROM preview_wiring_map_v6_props;
```

### Find Background paths for all previews
```sql
SELECT
    Name            AS PreviewName,
    IFNULL(BackgroundFile, '(none)') AS BackgroundFile
FROM previews
ORDER BY Name COLLATE NOCASE;
```

### Master props for a specific preview (includes DeviceType='None')
```sql
SELECT *
FROM preview_wiring_map_v6
WHERE Source = 'PROP' AND PreviewName = :preview_name;
```

### Count of props per preview
```sql
SELECT PreviewName, COUNT(*) AS PropCount
FROM preview_wiring_map_v6_props
GROUP BY PreviewName
ORDER BY PreviewName COLLATE NOCASE;
```

### QA check for wiring issues
```sql
SELECT Issue, PreviewName, Display_Name, Network, Controller, StartChannel, EndChannel
FROM breaking_check_v6
ORDER BY Issue, PreviewName, Network, Controller, StartChannel;
```

### Inspect wiring view (sorted, all sources)
```sql
SELECT *
FROM preview_wiring_sorted_v6
LIMIT 50;
```
