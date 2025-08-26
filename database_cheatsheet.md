# MSB Database Cheat Sheet

## SQL Queries

Here are some useful SQLite queries you can run against `lor_output_v6.db`.

### List all unique controllers and the networks they are used on
```sql
SELECT DISTINCT
    Controller,
    Network
FROM preview_wiring_sorted_v6
WHERE Controller IS NOT NULL
  AND DeviceType <> 'DMX'
ORDER BY Network, Controller;
```

### Find all props with DeviceType=None (physical-only, no channels)
```sql
SELECT PreviewId, PropID, Name, LORComment, Lights
FROM props
WHERE DeviceType = 'None';
```

### Count how many DeviceType=None props exist by Preview
```sql
SELECT PreviewId, COUNT(*) AS NoneCount
FROM props
WHERE DeviceType = 'None'
GROUP BY PreviewId;
```

### List all props with their device type
```sql
SELECT PreviewId, PropID, Name, LORComment, DeviceType
FROM props
ORDER BY DeviceType, LORComment;
```

### Inspect wiring view (sorted)
```sql
SELECT *
FROM preview_wiring_sorted_v6
LIMIT 50;
```
### List all previews that have controllers with spare channels (using MaxChannels)
```sql
WITH vw AS (
  SELECT *
  FROM preview_wiring_sorted_v6
  WHERE Controller IS NOT NULL
),
pvmap AS (
  SELECT PreviewId, Name AS PreviewName
  FROM previews
),
cap AS (
  SELECT
    pvmap.PreviewName,
    vw.Controller,
    vw.Network,
    COALESCE(
      MAX(CASE WHEN p.MaxChannels IS NOT NULL AND p.MaxChannels > 0 THEN p.MaxChannels END),
      CASE WHEN MAX(CASE WHEN p.DeviceType = 'DMX' THEN 1 ELSE 0 END) = 1
           THEN 512
           ELSE 16
      END
    ) AS Capacity
  FROM vw
  JOIN pvmap
    ON pvmap.PreviewName = vw.PreviewName
  LEFT JOIN props p
    ON p.PreviewId = pvmap.PreviewId
   AND p.UID = vw.Controller
   AND p.Network = vw.Network
  GROUP BY pvmap.PreviewName, vw.Controller, vw.Network
),
usage AS (
  SELECT
    PreviewName,
    Controller,
    Network,
    MIN(StartChannel) AS FirstUsedChannel,
    MAX(EndChannel)   AS LastUsedChannel
  FROM vw
  GROUP BY PreviewName, Controller, Network
)
SELECT
  u.PreviewName,
  u.Controller,
  u.Network,
  c.Capacity        AS MaxChannels,
  u.FirstUsedChannel,
  u.LastUsedChannel,
  (c.Capacity - u.LastUsedChannel) AS SpareChannels
FROM usage u
JOIN cap c
  ON c.PreviewName = u.PreviewName
 AND c.Controller  = u.Controller
 AND c.Network     = u.Network
WHERE (c.Capacity - u.LastUsedChannel) > 0
ORDER BY u.PreviewName, u.Controller, u.Network;
```
