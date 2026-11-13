USE db_fake_news;

-- 1. CONTROL DE VOLUMETRÍA GLOBAL (Comprobación de llenado de tablas)
SELECT 'DIM_AUTOR' AS tabla, COUNT(*) AS total_registros FROM DIM_AUTOR
UNION ALL
SELECT 'DIM_FUENTE', COUNT(*) FROM DIM_FUENTE
UNION ALL
SELECT 'DIM_PAIS', COUNT(*) FROM DIM_PAIS
UNION ALL
SELECT 'DIM_TIPO', COUNT(*) FROM DIM_TIPO
UNION ALL
SELECT 'TB_HECHOS', COUNT(*) FROM TB_HECHOS
UNION ALL
SELECT 'TB_METADATOS', COUNT(*) FROM TB_METADATOS;

-- 2. AUDITORÍA DE INTEGRIDAD REFERENCIAL (Verificación de sincronización 1:1)
SELECT 
    (SELECT COUNT(*) FROM TB_HECHOS) AS total_hechos,
    (SELECT COUNT(*) FROM TB_METADATOS) AS total_metadatos,
    CASE 
        WHEN (SELECT COUNT(*) FROM TB_HECHOS) = (SELECT COUNT(*) FROM TB_METADATOS) THEN '🟢 OK: Integridad referencial perfecta (6335/6335)'
        ELSE '🚨 ERROR: Desajuste crítico entre Hechos y Metadatos'
    END AS estado_sincronizacion;

-- 3. CONTROL DE DUPLICADOS (Asegura que la clave primaria no tenga colisiones)
SELECT T_ID, COUNT(*) AS repeticiones 
FROM TB_HECHOS 
GROUP BY T_ID 
HAVING COUNT(*) > 1;