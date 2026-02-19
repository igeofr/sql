WITH
-- =============================================
-- CTE 1 : Taille des tables et des index
-- =============================================
-- Cette CTE récupère la taille totale, la taille des données et la taille des index
-- pour chaque table utilisateur (hors schémas système).
-- Utilise :
--   - pg_total_relation_size : taille totale (table + index + TOAST)
--   - pg_table_size : taille des données uniquement
--   - pg_indexes_size : taille des index uniquement
--   - pg_size_pretty : formate la taille en Ko/Mo/Go pour une lecture facile
-- =============================================
table_sizes AS (
    SELECT
        n.nspname AS schema_name,          -- Nom du schéma
        c.relname AS table_name,          -- Nom de la table
        pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,  -- Taille totale formatée
        pg_size_pretty(pg_table_size(c.oid)) AS table_size,            -- Taille des données formatée
        pg_size_pretty(pg_indexes_size(c.oid)) AS indexes_size        -- Taille des index formatée
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid  -- Jointure avec les schémas
    WHERE c.relkind = 'r'  -- Seules les tables (pas les vues, index, etc.)
      AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')  -- Exclut les schémas système
),

-- =============================================
-- CTE 2 : Statistiques d'accès (I/O)
-- =============================================
-- Cette CTE récupère les statistiques de lectures/écritures pour chaque table :
--   - Scans séquentiels (lecture complète de la table)
--   - Scans via index
--   - Nombre de lignes vivantes/mortes
--   - Dernière date d'autovacuum
-- Elle calcule aussi :
--   - La différence entre scans séquentiels et scans indexés (indice de performance)
--   - Le statut des index manquants (si trop de scans séquentiels)
--   - Le statut de besoin de VACUUM (basé sur les lignes mortes et la date du dernier autovacuum)
-- =============================================
table_io_stats AS (
    SELECT
        s.schemaname AS schema_name,          -- Nom du schéma
        c.relname AS table_name,             -- Nom de la table
        s.seq_scan AS total_seq_scan,        -- Nombre total de scans séquentiels
        s.idx_scan AS total_index_scan,      -- Nombre total de scans via index
        s.seq_scan - s.idx_scan AS scan_difference,  -- Différence : indice de performance (plus c'est élevé, plus un index pourrait aider)
        c.reltuples AS live_rows,            -- Nombre estimé de lignes vivantes
        s.n_dead_tup AS dead_rows,           -- Nombre de lignes mortes (à nettoyer par VACUUM)
        s.last_autovacuum,                   -- Date du dernier autovacuum automatique
        -- Évaluation de la nécessité d'un index
        CASE
            WHEN s.seq_scan - s.idx_scan > 100 THEN 'Missing Index Likely'      -- Beaucoup de scans séquentiels inutiles
            WHEN s.seq_scan > 0 AND s.idx_scan = 0 THEN 'Potential Missing Index' -- Scans séquentiels mais aucun scan indexé
            ELSE 'No Missing Index Detected'                                       -- Pas de problème détecté
        END AS missing_index_status,
        -- Analyse des besoins en VACUUM
        CASE
            WHEN s.n_dead_tup > 1000 THEN 'VACUUM Urgent'          -- Plus de 1000 lignes mortes : urgent
            WHEN s.n_dead_tup > 500 THEN 'VACUUM Recommended'      -- Plus de 500 lignes mortes : recommandé
            WHEN s.last_autovacuum IS NULL OR (EXTRACT(EPOCH FROM (NOW() - s.last_autovacuum)) / 86400) > 7 THEN 'VACUUM Overdue'  -- Dernier autovacuum il y a plus de 7 jours
            ELSE 'No VACUUM Needed'                                  -- Pas de besoin identifié
        END AS vacuum_status
    FROM pg_stat_user_tables s
    JOIN pg_class c ON s.relid = c.oid  -- Jointure avec les métadonnées des tables
    WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')  -- Exclut les schémas système
),

-- =============================================
-- CTE 3 : Verrous sur les tables
-- =============================================
-- Cette CTE compte les verrous actifs sur chaque table, avec :
--   - Le nombre total de verrous
--   - Le nombre de verrous exclusifs (les plus restrictifs)
--   - Le nombre de verrous en attente (blocages)
-- Utile pour identifier les tables soumises à des contentions.
-- =============================================
table_locks AS (
    SELECT
        n.nspname AS schema_name,          -- Nom du schéma
        c.relname AS table_name,          -- Nom de la table
        COUNT(*) AS lock_count,            -- Nombre total de verrous
        SUM(CASE WHEN l.mode = 'ExclusiveLock' THEN 1 ELSE 0 END) AS exclusive_lock_count,  -- Nombre de verrous exclusifs
        SUM(CASE WHEN l.granted = false THEN 1 ELSE 0 END) AS waiting_lock_count   -- Nombre de verrous en attente (blocages)
    FROM pg_locks l
    JOIN pg_class c ON l.relation = c.oid  -- Jointure avec les tables
    JOIN pg_namespace n ON c.relnamespace = n.oid  -- Jointure avec les schémas
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')  -- Exclut les schémas système
    GROUP BY n.nspname, c.relname  -- Regroupement par schéma et table
),

-- =============================================
-- CTE 4 : Index non utilisés
-- =============================================
-- Cette CTE identifie les index jamais utilisés (idx_scan = 0).
-- Les index inutilisés peuvent être supprimés pour :
--   - Libérer de l'espace disque
--   - Accélérer les écritures (moins d'index à maintenir)
-- Utilise STRING_AGG pour concaténer les noms des index inutilisés par table.
-- =============================================
unused_indexes AS (
    SELECT
        n.nspname AS schema_name,          -- Nom du schéma
        c.relname AS table_name,          -- Nom de la table
        STRING_AGG(i.relname, ', ') AS unused_index_names  -- Liste des index inutilisés, séparés par des virgules
    FROM pg_stat_user_indexes s
    JOIN pg_index idx ON s.indexrelid = idx.indexrelid  -- Jointure avec les métadonnées des index
    JOIN pg_class i ON idx.indexrelid = i.oid            -- Jointure avec les noms des index
    JOIN pg_class c ON idx.indrelid = c.oid             -- Jointure avec les tables
    JOIN pg_namespace n ON c.relnamespace = n.oid       -- Jointure avec les schémas
    WHERE s.idx_scan = 0  -- Seuls les index jamais scannés
      AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')  -- Exclut les schémas système
    GROUP BY n.nspname, c.relname  -- Regroupement par schéma et table
),

-- =============================================
-- CTE 5 : Index redondants
-- =============================================
-- Cette CTE identifie les index redondants, c'est-à-dire ceux qui :
--   - Portent sur les mêmes colonnes
--   - Dans le même ordre
-- Les index redondants peuvent être supprimés pour :
--   - Libérer de l'espace disque
--   - Accélérer les écritures
-- Utilise STRING_AGG pour lister les index redondants avec un index donné.
-- =============================================
redundant_indexes AS (
    SELECT
        n.nspname AS schema_name,          -- Nom du schéma
        c.relname AS table_name,          -- Nom de la table
        i1.relname AS index_name,         -- Nom de l'index redondant
        STRING_AGG(i2.relname, ', ') AS redundant_with  -- Liste des index redondants avec i1, séparés par des virgules
    FROM pg_index idx1
    JOIN pg_index idx2 ON
        idx1.indrelid = idx2.indrelid AND       -- Même table
        idx1.indexrelid != idx2.indexrelid AND   -- Index différents
        array_to_string(idx1.indkey, ' ') = array_to_string(idx2.indkey, ' ')  -- Même colonnes dans le même ordre
    JOIN pg_class i1 ON idx1.indexrelid = i1.oid  -- Nom de l'index 1
    JOIN pg_class i2 ON idx2.indexrelid = i2.oid  -- Nom de l'index 2
    JOIN pg_class c ON idx1.indrelid = c.oid      -- Nom de la table
    JOIN pg_namespace n ON c.relnamespace = n.oid -- Nom du schéma
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')  -- Exclut les schémas système
    GROUP BY n.nspname, c.relname, i1.relname  -- Regroupement par schéma, table et index
)

-- =============================================
-- Requête principale : Résultat final combiné
-- =============================================
-- Cette requête combine toutes les CTEs pour produire un rapport complet par table :
--   - Taille (totale, données, index)
--   - Statistiques d'accès (scans, lignes vivantes/mortes)
--   - Statut des index (manquants, inutilisés, redondants)
--   - Verrous (nombre, exclusifs, en attente)
--   - Besoin de maintenance (VACUUM)
-- Trié par taille décroissante pour cibler les tables les plus volumineuses.
-- =============================================
SELECT
    ts.schema_name,                     -- Nom du schéma
    ts.table_name,                      -- Nom de la table
    ts.total_size,                      -- Taille totale (format lisible)
    ts.table_size,                      -- Taille des données (format lisible)
    ts.indexes_size,                    -- Taille des index (format lisible)
    tio.total_seq_scan,                 -- Nombre de scans séquentiels
    tio.total_index_scan,               -- Nombre de scans via index
    tio.scan_difference,                -- Différence scans séquentiels - scans indexés
    tio.live_rows,                      -- Nombre de lignes vivantes
    tio.dead_rows,                      -- Nombre de lignes mortes
	tio.last_autovacuum,                -- Date du dernier autovacuum
    tio.vacuum_status,                  -- Statut de besoin de VACUUM
    tl.lock_count,                      -- Nombre total de verrous
    tl.exclusive_lock_count,            -- Nombre de verrous exclusifs
    tl.waiting_lock_count,              -- Nombre de verrous en attente
    tio.missing_index_status,           -- Statut de détection d'index manquants
    CASE WHEN ui.unused_index_names IS NOT NULL THEN 'Oui' ELSE 'Non' END AS has_unused_index,  -- Présence d'index inutilisés
    ui.unused_index_names AS unused_index_names,  -- Liste des index inutilisés
    CASE WHEN ri.index_name IS NOT NULL THEN 'Oui' ELSE 'Non' END AS has_redundant_index,  -- Présence d'index redondants
    ri.index_name AS redundant_index_name,        -- Nom d'un index redondant
    ri.redundant_with AS redundant_with            -- Liste des index redondants avec redundant_index_name
FROM table_sizes ts
-- Jointures avec les autres CTEs pour combiner toutes les informations
LEFT JOIN table_io_stats tio ON ts.schema_name = tio.schema_name AND ts.table_name = tio.table_name
LEFT JOIN table_locks tl ON ts.schema_name = tl.schema_name AND ts.table_name = tl.table_name
LEFT JOIN unused_indexes ui ON ts.schema_name = ui.schema_name AND ts.table_name = ui.table_name
LEFT JOIN redundant_indexes ri ON ts.schema_name = ri.schema_name AND ts.table_name = ri.table_name
-- Tri par taille décroissante pour cibler les tables les plus volumineuses
ORDER BY pg_total_relation_size((ts.schema_name || '.' || ts.table_name)::regclass) DESC;
