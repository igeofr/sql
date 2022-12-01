-- Cercle par 3 points
# Calcul : https://www.geeksforgeeks.org/equation-of-circle-when-three-points-on-the-circle-are-given/

DROP TABLE IF EXISTS schema.table;
CREATE TABLE IF NOT EXISTS schema.table AS
(SELECT * ,
-- Création du cercle
ST_SetSRID(st_buffer(ST_MakePoint(x0, y0),(ROUND(CAST(sqrt(x0 * x0 + y0 * y0 - (-pow(x1, 2) - pow(y1, 2) -
2 * (((power(x1, 2) - power(x3, 2)) * (y1 - y2) + (power(y1, 2) - power(y3, 2)) * (y1 - y2) +
(power(x2, 2) - pow(x1, 2)) * (y1 - y3) + (power(y2, 2) - power(y1, 2)) * (y1 - y3)) /
(2 * ((x3 - x1) * (y1 - y2) - (x2 - x1) * (y1 - y3)))) * x1 - 2 * (((power(x1, 2) - power(x3, 2)) * (x1 - x2) + (power(y1, 2) - power(y3, 2)) *
(x1 - x2) + (power(x2, 2) - power(x1, 2)) * (x1 - x3) +
(power(y2, 2) - power(y1, 2)) * (x1 - x3)) / (2 *
((y3 - y1) * (x1 - x2) - (y2 - y1) * (x1 - x3)))) * y1)) AS numeric), 5)), 'quad_segs=15'),2154)::geometry(Polygon,2154) as geom,
-- Calcul du rayon
ROUND(CAST(sqrt(x0 * x0 + y0 * y0 - (-pow(x1, 2) - pow(y1, 2) -
2 * (((power(x1, 2) - power(x3, 2)) * (y1 - y2) + (power(y1, 2) - power(y3, 2)) * (y1 - y2) +
(power(x2, 2) - pow(x1, 2)) * (y1 - y3) + (power(y2, 2) - power(y1, 2)) * (y1 - y3)) /
(2 * ((x3 - x1) * (y1 - y2) - (x2 - x1) * (y1 - y3)))) * x1 - 2 * (((power(x1, 2) - power(x3, 2)) * (x1 - x2) + (power(y1, 2) - power(y3, 2)) *
(x1 - x2) + (power(x2, 2) - power(x1, 2)) * (x1 - x3) +
(power(y2, 2) - power(y1, 2)) * (x1 - x3)) / (2 *
((y3 - y1) * (x1 - x2) - (y2 - y1) * (x1 - x3)))) * y1)) AS numeric), 2)::double precision AS rayon
FROM(
SELECT *,
-- Calcul X du centre du cercle
-1*(((power(x1, 2) - power(x3, 2)) * (y1 - y2) + (power(y1, 2) - power(y3, 2)) * (y1 - y2) +
(power(x2, 2) - pow(x1, 2)) * (y1 - y3) + (power(y2, 2) - power(y1, 2)) * (y1 - y3)) /
(2 * ((x3 - x1) * (y1 - y2) - (x2 - x1) * (y1 - y3)))) AS x0,
-- Calcul Y du centre du cercle
-1*(((power(x1, 2) - power(x3, 2)) * (x1 - x2) + (power(y1, 2) - power(y3, 2)) *
(x1 - x2) + (power(x2, 2) - power(x1, 2)) * (x1 - x3) +
(power(y2, 2) - power(y1, 2)) * (x1 - x3)) / (2 *
((y3 - y1) * (x1 - x2) - (y2 - y1) * (x1 - x3)))) as y0

FROM 
(SELECT *, 
LEAD(x1,1) OVER (ORDER BY id) as x2,
LEAD(y1,1) OVER (ORDER BY id) as y2,
LEAD(x1,2) OVER (ORDER BY id) as x3,
LEAD(y1,2) OVER (ORDER BY id) as y3
FROM 
(SELECT id, ST_X(geom) as x1, ST_Y(geom) as y1 FROM schema.table_points LIMIT 3) a LIMIT 1) b)c
);
