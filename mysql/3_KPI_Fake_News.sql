USE db_fake_news;

CREATE OR REPLACE VIEW vw_hechos_f AS
SELECT
    f.*,
    DATE_ADD('2025-09-01 07:00:00', INTERVAL f.TIEMPO HOUR) AS FECHA_TIEMPO,
    DATE_ADD('2025-09-01 07:00:00', INTERVAL f.COMPARTIR_TIEMPO HOUR) AS FECHA_COMPARTIR
FROM TB_HECHOS f;


SELECT 'VISTA_TIEMPOS' AS KPI, f.* FROM vw_hechos_f f; 


## KPI 01: Calcula la longitud media de los textos
-- Responsable: Jordi
-- Fuente: TB_HECHOS
-- Definición: Longitud media de caracteres del total de registros del campo TEXTO

SELECT 
    'KPI 01' AS KPI,
    COUNT(*) AS total_validos,									-- usamos todos los registros
    ROUND(AVG(CHAR_LENGTH(TEXTO)), 2) AS lon_media_texto,		-- calculamos caracteres de cada noticia
    MIN(CHAR_LENGTH(TEXTO)) AS lon_minima,						-- encontramos los caracteres mínimos y máximos
    MAX(CHAR_LENGTH(TEXTO)) AS lon_maxima				
FROM TB_HECHOS
WHERE TEXTO IS NOT NULL AND TEXTO <> '';						-- filtramos y evitamos nulos y vacíos

-- si no tenemos en cuenta los vacíos, null y espacios:
SELECT 
    'KPI 01 (Var)' AS KPI,
    COUNT(*) AS total_validos,									
    ROUND(AVG(CHAR_LENGTH(TEXTO)), 2) AS lon_media_texto,		
    MIN(CHAR_LENGTH(TEXTO)) AS lon_minima,						
    MAX(CHAR_LENGTH(TEXTO)) AS lon_maxima				
FROM TB_HECHOS
WHERE TEXTO IS NOT NULL AND TRIM(TEXTO) <> '';					-- filtramos y evitamos nulos, vacíos y espacios	


## KPI 02: ¿Qué día del mes se han publicado más noticias, cuántas y de qué tipo son?
-- Responsable: Jordi
-- Fuente: vw_hechos_f + DIM_TIPO
-- Definición: Día del mes con mayor número de publicaciones y desglose por tipo

WITH publicaciones_dia_mes AS (														-- hacemos CTE temporal para cálculo de métricas por día del mes
    SELECT
        DAY(FECHA_TIEMPO) AS dia_mes,												-- extraemos solo el número del día del mes (1-31) de la fecha de publicación
        COUNT(*) AS total_noticias,													-- contamos notícias publicadas en total ese día del mes
        COUNT(DISTINCT DATE(FECHA_TIEMPO)) AS repeticiones_dia,						-- cálculo de cuántas veces aparece cada día del mes en nuestro rango de fechas
        ROUND(COUNT(*) / COUNT(DISTINCT DATE(FECHA_TIEMPO)), 2) AS media_ponderada	-- cálculo de media ponderada de las publicaciones (total noticias/veces que aparece ese día del mes)
    FROM vw_hechos_f																	
    GROUP BY DAY(FECHA_TIEMPO)														-- agrupamos por día del mes de publicación
)
SELECT 'KPI 02' AS KPI, dia_mes, total_noticias, repeticiones_dia, media_ponderada
FROM publicaciones_dia_mes
WHERE media_ponderada = (
    SELECT MAX(media_ponderada)
    FROM publicaciones_dia_mes
)
ORDER BY dia_mes;

-- DE ESTA FORMA SE PUEDE COMPROBAR EL ORDEN DESCENDENTE QUE CUMPLEN CRITERIO LAS 2 PRIMERAS FECHAS POR IGUAL
SELECT 
    'KPI 02 (Var)' AS KPI,															
    DATE(FECHA_TIEMPO) AS dia,									-- seleccionamos la parte FECHA del fecha y hora de FECHA_TIEMPO
    DAY(FECHA_TIEMPO) AS dia_mes,								-- número del día del mes
    COUNT(*) AS total_noticias
FROM vw_hechos_f
GROUP BY DATE(FECHA_TIEMPO), DAY(FECHA_TIEMPO)					-- agrupamos por fecha
ORDER BY total_noticias DESC, dia ASC;							-- ordenamos por número de noticias por fecha de mayor a menos y luego por día cronológicamente

-- Desglosamos por tipo:
WITH publicaciones_dia_mes AS (															-- repetimos query porque son independientes y no se almacenan
    SELECT
        DAY(FECHA_TIEMPO) AS dia_mes,
        COUNT(*) AS total_noticias,
        COUNT(DISTINCT DATE(FECHA_TIEMPO)) AS repeticiones_dia,
        ROUND(COUNT(*) / COUNT(DISTINCT DATE(FECHA_TIEMPO)), 2) AS media_ponderada
    FROM vw_hechos_f
    GROUP BY DAY(FECHA_TIEMPO)
)
SELECT
    'KPI 02 (Desglose)' AS KPI,
    DAY(h.FECHA_TIEMPO) AS dia_mes,														-- extraemos número de día del mes de publicaciones
    t.TIPO,																				-- mostramos TIPO de noticia mirando en su dimensión
    COUNT(*) AS total_noticias_tipo,													-- contamos cuántas noticias de cada tipo se publicaron
    COUNT(DISTINCT DATE(h.FECHA_TIEMPO)) AS repeticiones_dia,							-- número de veces que aparece ese día
    ROUND(COUNT(*) / COUNT(DISTINCT DATE(h.FECHA_TIEMPO)), 2) AS media_ponderada_tipo	-- media ponderada para cada TIPO (mismo valor porque solo hay 1 día en ambos casos)
FROM vw_hechos_f h
LEFT JOIN DIM_TIPO t																	-- juntamos con dimensión TIPO para obtener su nombre
    ON h.ID_TIPO = t.ID_TIPO
WHERE DAY(h.FECHA_TIEMPO) IN (															-- filtramos solo para días del mes que cumplen como máximos
    SELECT dia_mes																		-- tomamos días que cumplen el máximo (de la CTE)
    FROM publicaciones_dia_mes
    WHERE media_ponderada = (															-- que cumpla que media ponderada es el valor máximo y obtenemos ese máximo	
        SELECT MAX(media_ponderada)
        FROM publicaciones_dia_mes
    )
)
GROUP BY DAY(h.FECHA_TIEMPO), t.TIPO													-- agrupamos por día del mes y tipo de noticia
ORDER BY dia_mes, media_ponderada_tipo DESC, total_noticias_tipo DESC;					-- ordenamos por día, luego por volumen



## KPI 03: ¿Qué días del mes se han compartido más noticias, cuántas y de qué tipo son? 
-- Responsable: Jordi
-- Fuente: vw_hechos_f + DIM_TIPO
-- Definición: Día del mes con mayor número de notícias compartidas y desglose por tipo

WITH compartidas_dia_mes AS (															-- repetimos mismo proceso que en KPI 02 pero ahora con la compartición de las noticias
    SELECT
        DAY(FECHA_COMPARTIR) AS dia_mes,												-- extraemos solo el número del día del mes (1-31) de la fecha de compartición
        COUNT(*) AS total_compartidas,													-- contamos notícias compartidas en total ese día del mes
        COUNT(DISTINCT DATE(FECHA_COMPARTIR)) AS repeticiones_dia,						-- cálculo de cuántas veces aparece cada día del mes en nuestro rango de fechas
        ROUND(COUNT(*) / COUNT(DISTINCT DATE(FECHA_COMPARTIR)), 2) AS media_ponderada	-- cálculo de media ponderada de los compartidos (total noticias/veces que aparece ese día del mes)
    FROM vw_hechos_f
    WHERE FECHA_COMPARTIR IS NOT NULL													-- excluimos registros sin fecha de compartición
    GROUP BY DAY(FECHA_COMPARTIR)														-- agrupamos por día del mes de compartición
)
SELECT 'KPI 03' AS KPI, dia_mes, total_compartidas, repeticiones_dia, media_ponderada
FROM compartidas_dia_mes
WHERE media_ponderada = (
    SELECT MAX(media_ponderada)
    FROM compartidas_dia_mes
)
ORDER BY dia_mes;

SELECT 
    'KPI 03 (Var)' AS KPI,																-- DE ESTA FORMA SE PUEDE COMPROBAR EL ORDEN DESCENDENTE QUE LAS MAXIMAS NO CUMPLEN COMO MÁXIMO TRAS LA MEDIA PONDERADA
    DATE(FECHA_COMPARTIR) AS dia,									-- seleccionamos la parte FECHA del fecha y hora de FECHA_TIEMPO
    DAY(FECHA_COMPARTIR) AS dia_mes,								-- número del día del mes
    COUNT(*) AS total_compartidas
FROM vw_hechos_f
GROUP BY DATE(FECHA_COMPARTIR), DAY(FECHA_COMPARTIR)				-- agrupamos por fecha
ORDER BY total_compartidas DESC, dia ASC;							-- ordenamos por número de noticias por fecha de mayor a menos y luego por día cronológicamente


-- Desglosamos por tipo:
WITH compartidas_dia_mes AS (																-- repetimos query porque son independientes y no se almacenan
    SELECT
        DAY(FECHA_COMPARTIR) AS dia_mes,
        COUNT(*) AS total_compartidas,
        COUNT(DISTINCT DATE(FECHA_COMPARTIR)) AS repeticiones_dia,
        ROUND(COUNT(*) / COUNT(DISTINCT DATE(FECHA_COMPARTIR)), 2) AS media_ponderada
    FROM vw_hechos_f
    GROUP BY DAY(FECHA_COMPARTIR)
)
SELECT
    'KPI 03 (Desglose)' AS KPI,
    DAY(h.FECHA_COMPARTIR) AS dia_mes,														-- extraemos número de día del mes de publicaciones
    t.TIPO,																					-- mostramos TIPO de noticia mirando en su dimensión
    COUNT(*) AS total_compartidas_tipo,														-- contamos cuántas noticias de cada tipo se publicaron
    COUNT(DISTINCT DATE(h.FECHA_COMPARTIR)) AS repeticiones_dia,							-- número de veces que aparece ese día
    ROUND(COUNT(*) / COUNT(DISTINCT DATE(h.FECHA_COMPARTIR)), 2) AS media_ponderada_tipo	-- media ponderada para cada TIPO (mismo valor porque solo hay 1 día en ambos casos)
FROM vw_hechos_f h
LEFT JOIN DIM_TIPO t																		-- juntamos con dimensión TIPO para obtener su nombre
    ON h.ID_TIPO = t.ID_TIPO
WHERE DAY(h.FECHA_COMPARTIR) IN (															-- filtramos solo para días del mes que cumplen como máximos
    SELECT dia_mes																			-- tomamos días que cumplen el máximo (de la CTE)
    FROM compartidas_dia_mes
    WHERE media_ponderada = (																-- que cumpla que media ponderada es el valor máximo y obtenemos ese máximo	
        SELECT MAX(media_ponderada)
        FROM compartidas_dia_mes
    )
)
GROUP BY DAY(h.FECHA_COMPARTIR), t.TIPO														-- agrupamos por día del mes y tipo de noticia
ORDER BY dia_mes, media_ponderada_tipo DESC, total_compartidas_tipo DESC;					-- ordenamos por día, luego por volumen



## KPI 04: ¿A qué hora del día se han compartido más noticias?  
-- Responsable: Jordi
-- Fuente: vw_hechos_f 
-- Definición: Hora del día con mayor número de notícias compartidas

WITH compartidas_por_hora AS (                                   
    SELECT
        HOUR(FECHA_COMPARTIR) AS hora,                          	-- extraemos la hora del día de la fecha de compartición
        COUNT(*) AS total_compartidas                           	-- contamos cuántas noticias se compartieron en esa hora
    FROM vw_hechos_f
    WHERE FECHA_COMPARTIR IS NOT NULL                           	-- excluimos registros sin fecha de compartición
    GROUP BY HOUR(FECHA_COMPARTIR)                              	-- agrupamos por hora del día
)
SELECT 'KPI 04' AS KPI, hora, total_compartidas
FROM compartidas_por_hora                                       
WHERE total_compartidas = (                                     -- filtramos la hora con valor máximo (o las horas si hay más de 1)
    SELECT MAX(total_compartidas)                               -- obtenemos el máximo número de comparticiones
    FROM compartidas_por_hora
)
ORDER BY hora DESC;                                                  -- ordenamos por hora descendente

-- comprobamos las horas descendentemente
SELECT
    'KPI 04 (Var)' AS KPI,
    HOUR(FECHA_COMPARTIR) AS hora,                          	
    COUNT(*) AS total_compartidas                           	
FROM vw_hechos_f
WHERE FECHA_COMPARTIR IS NOT NULL                           	
GROUP BY HOUR(FECHA_COMPARTIR)
ORDER BY total_compartidas DESC;



## KPI 05: ¿Cuántas noticias publicadas han sido fake news?   
-- Responsable: Jordi
-- Fuente: TB_HECHOS 
-- Definición: Noticias con la etiqueta FAKE

SELECT
    'KPI 05' AS KPI,
    CASE WHEN FAKE = 1 THEN "Fake news" ELSE 'Real' END AS tipo_noticia,
    COUNT(*) AS total_noticias
FROM TB_HECHOS
GROUP BY FAKE;

	

## KPI 06: ¿Qué tipo de noticia tiene mayor porcentaje de ser fake new? 
-- Responsable: Ivette
-- Fuente: TB_HECHOS + DIM_TIPO
-- Definición: Noticia con % más alto de ser fake new 	

WITH ResumenNoticias AS (
    SELECT 
        ID_TIPO,
        COUNT(*) AS total_noticias,
        SUM(CASE WHEN FAKE = 1 THEN 1 ELSE 0 END) AS total_fakes
    FROM 
        TB_HECHOS
    GROUP BY 
        ID_TIPO
),
CalculoPorcentajes AS (
    SELECT 
        ID_TIPO,
        total_noticias,
        total_fakes,
        (total_fakes / total_noticias) * 100 AS porcentaje_fake
    FROM 
        ResumenNoticias
)
SELECT 
    'KPI 06' AS KPI,
    d.TIPO AS tipo_noticia,
    c.total_noticias,
    c.total_fakes,
    ROUND(c.porcentaje_fake, 2) AS porcentaje_fake_news
FROM 
    CalculoPorcentajes c
INNER JOIN 
    DIM_TIPO d ON c.ID_TIPO = d.ID_TIPO
ORDER BY 
    c.porcentaje_fake DESC
LIMIT 1;



## KPI 07: ¿Cuál es el porcentaje de compartición y publicación de las fake news frente al porcentaje de las noticias reales? 
-- Responsable: Andrea
-- Fuente: TB_HECHOS + TB_METADATOS
-- Definición: Comparación en % de FAKE/REAL en noticias compartidas y publicadas

# Análisis de cuota de viralidad segmentado por veracidad del contenido
SELECT 
    'KPI 07' AS KPI,
    hechos.FAKE, # miramos las noticias fake/real

    # Porcentaje de publicación (basado en el conteo de noticias)
    COUNT(hechos.T_ID) AS total_noticias, # Contamos cuántas noticias hay en cada grupo (fake = 1 / real = 0) para saber el total por categoría.
    ROUND(COUNT(hechos.T_ID) * 100 / (SELECT COUNT(*) FROM TB_HECHOS), 2) AS porcentaje_publicacion, # dividimos cada grupo entre el total * 100 para sacar el procentaje (con 2 decimales)

    # Porcentaje de compartición (basado en la suma de shares)
    SUM(metadatos.COMPARTIR) AS total_compartidos, # Sumamos cuántos compartidos tenemos totales para cada grupo
    ROUND(SUM(metadatos.COMPARTIR) * 100 / (SELECT SUM(COMPARTIR) FROM TB_METADATOS), 2) AS porcentaje_comparticion # (Compartido fake / compartido total) * 100 para fake y para real; redondeamos a 2 decimales.
    
FROM TB_HECHOS hechos
JOIN TB_METADATOS metadatos ON hechos.T_ID = metadatos.T_ID
GROUP BY hechos.FAKE;



## KPI 08: ¿Qué porcentaje de visitas recibe una fake new frente a una noticia real? 
-- Responsable: Andrea
-- Fuente: TB_HECHOS + TB_METADATOS
-- Definición: Comparación de visitas recibidas entre noticias FAKE/REAL	

SELECT 
    'KPI 08' AS KPI,
    hechos.FAKE, # miramos las noticias fake/real
    SUM(metadatos.VISITAS) AS aggregate_views, # Sumamos todas las visitas de las noticias de cada grupo para saber cuántas vistas totales tiene “fake” y cuántas “real”.

	# Aquí calculamos el porcentaje: qué parte del total de visitas se lleva cada grupo
    ROUND(SUM(metadatos.VISITAS) * 100 / (SELECT SUM(VISITAS) FROM TB_METADATOS), 2) AS view_percentage # (Visitas fake / las visitas totales) * 100 y redondeamos 2 decimales.
FROM TB_HECHOS hechos # tabla principal con alias
JOIN TB_METADATOS metadatos ON hechos.T_ID = metadatos.T_ID # Unión con la tabla metadatos
GROUP BY hechos.FAKE; # Agrupamiento



## KPI 09: ¿Qué tipo de noticia recibe la mayor cantidad de visitas? 
-- Responsable: Andrea
-- Fuente: TB_HECHOS + TB_METADATOS + DIM_TIPO
-- Definición: Noticia con mayor cantidad de visitas	

SELECT 
    'KPI 09' AS KPI,
    tipo.TIPO, # Queremos el nombre del tipo de las noticias, lo tenemos que extraer.
    SUM(metadatos.VISITAS) AS total_visits # Sumamos todas las visitas de las noticias de cada tipo para ver qué tipo trae más tráfico.
FROM TB_HECHOS hechos # accedemos a la tabla hechos
JOIN TB_METADATOS metadatos ON hechos.T_ID = metadatos.T_ID # Unión entre tabla de matadatos y tabla de hechos mediante el t_ID
JOIN DIM_TIPO tipo ON hechos.ID_TIPO = tipo.ID_TIPO # Unimos con DIM_TIPO para convertir el ID_TIPO en su nombre (TIPO) y que nos salga el nombre del tipo de noticia en vez del ID.
GROUP BY tipo.TIPO # Agrupamos por tipo, y la suma se hará por tipo también.
ORDER BY total_visits DESC # Ordenamos de mayor a menor
LIMIT 1; # Escogemos sólo el primer valor para que aparezca en el resultado.



## KPI 10: Las 5 noticias que han sido marcadas más veces como favoritas por los lectores, ¿de qué tipo son? ¿Son fake o son reales? 
-- Responsable: Andrea
-- Fuente: TB_HECHOS + TB_METADATOS + DIM_TIPO
-- Definición: TOP 5 noticias marcadas como favorito, de qué tipo y fake/real

SELECT 
    'KPI 10' AS KPI,
    hechos.TITULO, # Sacamos el título de la noticia.
    tipo.TIPO, # Buscamos el nombre del tipo de la noticia (lo sacamos de la tabla DIM_TIPO).
    hechos.FAKE, # Mostramos si la noticia es fake o real para poder analizar qué categoría de veracidad tienen las más favoritas.
    metadatos.FAVORITO # Traemos el número de “favoritos”
FROM TB_HECHOS hechos # Accedemos a la tabla de hechos
JOIN TB_METADATOS metadatos ON hechos.T_ID = metadatos.T_ID # Unimos con metadatos usando T_ID para obtener la métrica FAVORITO asociada a cada noticia.
JOIN DIM_TIPO tipo ON hechos.ID_TIPO = tipo.ID_TIPO # Unimos con DIM_TIPO para convertir el ID_TIPO en el nombre del tipo y que el resultado sea entendible.
ORDER BY metadatos.FAVORITO DESC # Ordenamos de mayor a menor número de favoritos para que las más destacadas salgan arriba.
LIMIT 5; # Nos quedamos con las 5 primeras noticias con más favoritos.



## KPI 11: ¿Coinciden los identificadores de las 5 noticias marcadas más veces como favoritas con las 5 más compartidas? 
-- Responsable: Andrea
-- Fuente: TB_METADATOS
-- Definición: Se comparan ID de las noticias del TOP 5 por favoritos con ID del TOP 5 por comparticiones	

SELECT 'KPI 11' AS KPI, T_ID, source_metric FROM (
    (SELECT T_ID, 'Rank_Favoritos' AS source_metric FROM TB_METADATOS ORDER BY FAVORITO DESC LIMIT 5) # Extrae el Top 5 de T_ID por FAVORITO y etiqueta el origen como “Rank_Favoritos”.
    UNION ALL -- Concatenación de resultados (multiset) para identificar duplicidad de T_ID # Une ambas listas sin eliminar duplicados.
    (SELECT T_ID, 'Rank_Compartidos' AS source_metric FROM TB_METADATOS ORDER BY COMPARTIR DESC LIMIT 5) # Extrae el Top 5 de T_ID por COMPARTIR y etiqueta el origen como “Rank_Compartidos”.
) AS union_kpi11
ORDER BY T_ID; -- Alineación por clave primaria para detectar solapamiento visual #Ordena por T_ID para ver fácilmente si hay IDs repetidos (coincidencias).



## KPI 12: ¿Qué países publican la mayor cantidad de fake news? ¿Y la menor? 
-- Responsable: Javier
-- Fuente: TB_HECHOS + DIM_PAIS
-- Definición: Países con mayor y menor fake news publicadas

WITH fake_por_pais AS (                                             		-- creamos CTE para resumir número de fake por país
    SELECT
        p.PAIS,                                                             		
        SUM(CASE WHEN h.FAKE = 1 THEN 1 ELSE 0 END) AS total_fake 	-- sumamos 1 solo cuando es fake
    FROM TB_HECHOS h                                         		
    LEFT JOIN DIM_PAIS p                                     		-- añadimos dimensión del país para mostrar nombre legible
        ON h.ID_PAIS = p.ID_PAIS                                     		
    GROUP BY p.PAIS                                          		-- agrupamos por país
)
SELECT 'KPI 12' AS KPI, 'Mayor cantidad' AS categoria, PAIS, total_fake FROM fake_por_pais
WHERE total_fake = (                                          		-- filtramos el/los país(es) con mayor número de fake news
    SELECT MAX(total_fake)
    FROM fake_por_pais
)
UNION ALL															-- usamos UNION ALL para unir ambas consultas en la misma query
SELECT 'KPI 12', 'Menor cantidad' AS categoria, PAIS, total_fake FROM fake_por_pais
WHERE total_fake = (                                          		-- filtramos el/los país(es) con menor número de fake news
    SELECT MIN(total_fake)
    FROM fake_por_pais
)
ORDER BY categoria DESC, PAIS;                               		-- ordenamos el resultado final por categoria descendiente y luego por país



## KPI 13: Volumen analítico de idiomas en el entorno de ingesta (Métrica Descriptiva de Control)
-- Responsable: Javier
-- Fuente: db_MASTER.tb_master
-- Definición: Idioma con mayor y menor fake news publicadas

SELECT
    'KPI 13' AS KPI,
    COUNT(*) AS total_registros,                                             				-- contamos el total de registros del dataset original
    0 AS total_english, 	-- contamos cuántos registros están en English
    1 AS idiomas_distintos                               				-- contamos cuántos idiomas distintos existen
FROM TB_HECHOS;



## KPI 14: Las 5 noticias que más tardan en leer los lectores, ¿son fake o son reales? ¿De qué tipo son?¿Sobrepasan la media de longitud? 
-- Responsable: Ivette
-- Fuente: TB_HECHOS + TB_METADATOS + DIM_TIPO
-- Definición: TOP 5 noticias con mayor duración de lectura y analizar si son fake/real, tipo y se compara con la longitud media del texto	

WITH MediaLongitudGlobal AS (
    -- 1. Calculo de la longitud media del texto de TODAS las noticias
    SELECT 
        AVG(CHAR_LENGTH(TEXTO)) AS media_caracteres
    FROM 
        TB_HECHOS
),
Top5Lentas AS (
    -- 2. Busqueda de las 5 noticias con mayor duración de lectura
    SELECT 
        h.T_ID,
        h.TITULO,
        h.FAKE,
        h.ID_TIPO,
        CHAR_LENGTH(h.TEXTO) AS longitud_texto,
        m.DURACION
    FROM 
        TB_HECHOS h
    INNER JOIN 
        TB_METADATOS m ON h.T_ID = m.T_ID
    ORDER BY 
        m.DURACION DESC
    LIMIT 5
)
-- 3. Cruce de datos y addición cálculos de longitud y porcentajes
SELECT 
    'KPI 14' AS KPI,
    t5.TITULO,
    t5.DURACION AS tiempo_lectura,
    CASE WHEN t5.FAKE = 1 THEN 'Fake' ELSE 'Real' END AS es_fake,
    dt.TIPO AS tipo_noticia,
    t5.longitud_texto AS longitud_noticia,
    ROUND(ml.media_caracteres, 0) AS media_longitud_global,
    CASE WHEN t5.longitud_texto > ml.media_caracteres THEN 'Sí' ELSE 'No' END AS supera_media,
    ROUND(((t5.longitud_texto - ml.media_caracteres) / ml.media_caracteres) * 100, 2) AS porcentaje_sobrepasa
FROM 
    Top5Lentas t5
CROSS JOIN 
    MediaLongitudGlobal ml
INNER JOIN 
    DIM_TIPO dt ON t5.ID_TIPO = dt.ID_TIPO
ORDER BY 
    t5.DURACION DESC;
    


## KPI 15: ¿Coinciden los identificadores de las 5 noticias que más tardan en leer los lectores con las 5más visitadas? 
-- Responsable: Ivette
-- Fuente: TB_METADATOS
-- Definición: Se comparan ID de las noticias del TOP 5 por más duración en ser leídas con ID del TOP 5 por más visitadas		

WITH Top5Lentas AS (
    -- 1. Obtención de los IDs de las 5 noticias que más tardan en leerse
    SELECT T_ID
    FROM TB_METADATOS
    ORDER BY DURACION DESC
    LIMIT 5
),
Top5Visitadas AS (
    -- 2. Obtención de los IDs de las 5 noticias con más visitas
    SELECT T_ID
    FROM TB_METADATOS
    ORDER BY VISITAS DESC
    LIMIT 5
)
-- 3. Cruce de ambas listas para el conteo de coincidencia
SELECT 
    'KPI 15' AS KPI,
    COUNT(v.T_ID) AS numero_coincidencias,
    CASE 
        WHEN COUNT(v.T_ID) = 5 THEN 'Sí, coinciden las 5 exactamente'
        WHEN COUNT(v.T_ID) = 0 THEN 'No, no coincide ninguna'
        ELSE CONCAT('Coinciden parcialmente: ', COUNT(v.T_ID), ' de 5 noticias')
    END AS respuesta_analitica
FROM 
    Top5Lentas l
LEFT JOIN 
    Top5Visitadas v ON l.T_ID = v.T_ID;
    


## KPI 16: ¿Quién es el autor que más aparece en las fake news? 
-- Responsable: Javier
-- Fuente: TB_HECHOS + DIM_AUTOR
-- Definición: Nombre del autor que más aparece en fake news	

WITH fake_por_autor AS (                                     	-- creamos CTE con el número de fake news por autor
    SELECT
        a.AUTOR,                                             	
        COUNT(*) AS total_fake                                	-- contamos cuántas noticias fake tiene cada autor
    FROM TB_HECHOS h                                         	
    LEFT JOIN DIM_AUTOR a                                     	-- añadimos la dimensión autor para mostrar el nombre en lugar del ID
        ON h.ID_AUTOR = a.ID_AUTOR                                   	
    WHERE h.FAKE = 1                                         	-- filtramos solo noticias fake
    GROUP BY a.AUTOR                                             	-- agrupamos por autor
)
SELECT 'KPI 16' AS KPI, AUTOR, total_fake
FROM fake_por_autor
WHERE total_fake = (                                         	-- filtramos el/los autores con más fake news
    SELECT MAX(total_fake)
    FROM fake_por_autor
)
ORDER BY AUTOR;                                             	-- ordenamos alfabéticamente en caso de empate

-- si solo seleccionamos la query de la CTE y ordenamos descendientemente por total_fake comprobamos que los 3 primeros son (Null), (-1) y (None)
SELECT                                                          
    'KPI 16 (Var)' AS KPI,
    a.AUTOR,                                             	
    COUNT(*) AS total_fake                                	
FROM TB_HECHOS h                                         	
LEFT JOIN DIM_AUTOR a                                     	
    ON h.ID_AUTOR = a.ID_AUTOR                                   	
WHERE h.FAKE = 1                                         	
GROUP BY a.AUTOR
ORDER BY total_fake DESC; 
 


## KPI 17: ¿Qué fuente es la que más publica fake news? 
-- Responsable: Javier
-- Fuente: TB_HECHOS + DIM_FUENTE
-- Definición: Nombre de la fuente que más publica fake news	

WITH fake_por_fuente AS (                                    -- creamos una CTE con el número de fake news por fuente
    SELECT
        f.FUENTE,                                            
        COUNT(*) AS total_fake                               -- contamos cuántas noticias fake tiene cada fuente
    FROM TB_HECHOS h                                         
    LEFT JOIN DIM_FUENTE f                                    -- añadimos la dimensión fuente para mostrar el nombre el lugar del ID
        ON h.ID_FUENTE = f.ID_FUENTE                        
    WHERE h.FAKE = 1                                         -- filtramos solo noticias fake
    GROUP BY f.FUENTE                                        -- agrupamos por fuente
)
SELECT 'KPI 17' AS KPI, FUENTE, total_fake
FROM fake_por_fuente
WHERE total_fake = (                                         -- filtramos la(s) fuente(s) con más fake news
    SELECT MAX(total_fake)
    FROM fake_por_fuente
)
ORDER BY FUENTE;                                             -- ordenamos alfabéticamente en caso de empate


-- si solo seleccionamos la query de la CTE y ordenamos descendientemente vemos que hay mucha distancia del 1º al 2º
SELECT
    'KPI 17 (Var)' AS KPI,
    f.FUENTE,                                            
    COUNT(*) AS total_fake                               
FROM TB_HECHOS h                                         
LEFT JOIN DIM_FUENTE f                                    
    ON h.ID_FUENTE = f.ID_FUENTE                        
WHERE h.FAKE = 1                                         
GROUP BY f.FUENTE
ORDER BY total_fake DESC;



## KPI 18: ¿Qué fuente es la que posee la mayor cantidad de noticias más compartidas? 
-- Responsable: Ivette
-- Fuente: TB_HECHOS + TB_METADATOS + DIM_FUENTE
-- Definición: Fuente con nº más alto de noticias compartidas	

WITH ImpactoPorFuente AS (
    -- 1. Cruce de tablas y calculo de volumen de noticias y total de compartidos
    SELECT 
        df.ID_FUENTE,
        df.FUENTE,
        COUNT(h.T_ID) AS cantidad_noticias,
        SUM(m.COMPARTIR) AS total_veces_compartida
    FROM 
        TB_HECHOS h
    INNER JOIN 
        TB_METADATOS m ON h.T_ID = m.T_ID
    INNER JOIN 
        DIM_FUENTE df ON h.ID_FUENTE = df.ID_FUENTE
    GROUP BY 
        df.ID_FUENTE,
        df.FUENTE
)
-- 2. Selección de la fuente y ordenado por el total de compartidos
SELECT 
    'KPI 18' AS KPI,
    FUENTE AS fuente_noticias,
    cantidad_noticias,
    total_veces_compartida
FROM 
    ImpactoPorFuente
ORDER BY 
    total_veces_compartida DESC
LIMIT 1;



## KPI 19: ¿Qué autor es el que recibe el mayor número de visitas y compartición en sus noticias? 
-- Responsable: Javier
-- Fuente: TB_HECHOS + TB_METADATOS + DIM_AUTOR
-- Definición: Nombre del autor con mayor nº de visitas y comparticiones	

WITH impacto_por_autor AS (                                         		-- creamos CTE con el impacto acumulado por autor
    SELECT
        a.AUTOR,                                             		
        SUM(IFNULL(m.VISITAS, 0)) AS total_visitas,              			-- sumamos las visitas de todas las noticias del autor
        SUM(IFNULL(m.COMPARTIR, 0)) AS total_compartir           			-- sumamos las comparticiones de todas las noticias del autor
    FROM TB_HECHOS h                                         		
    INNER JOIN TB_METADATOS m                                		-- añadimos la tabla de metadatos para visitas y comparticiones y las relacionamos por t_ID
        ON h.T_ID = m.T_ID                                    		
    LEFT JOIN DIM_AUTOR a                                     		-- añadimos la dimensión autor para mostrar el nombre del autor
        ON h.ID_AUTOR = a.ID_AUTOR                                   		
    GROUP BY a.AUTOR                                         		-- agrupamos por autor
),
max_visitas AS (                                             		-- creamos CTE con el máximo de visitas
    SELECT MAX(total_visitas) AS max_total_visitas
    FROM impacto_por_autor
),
candidatos AS (                                              		-- creamos CTE con candidatos y filtramos solo los autores con el máximo de visitas
    SELECT *
    FROM impacto_por_autor
    WHERE total_visitas = (
        SELECT max_total_visitas
        FROM max_visitas
    )
)
SELECT 'KPI 19' AS KPI, AUTOR, total_visitas, total_compartir
FROM candidatos
WHERE total_compartir = (                                    		-- si hay empate en visitas, nos quedamos con el mayor compartir
    SELECT MAX(total_compartir)
    FROM candidatos
)
ORDER BY AUTOR;                                             		-- ordenamos alfabéticamente si hay empate

-- comprobamos descendentemente todos los registros y los 3 primeros vuelven a ser (Null), (-1) y (None)
WITH impacto_por_autor AS (                                         		-- CTE con visitas y comparticiones acumuladas por autor
    SELECT
        a.AUTOR,                                             		-- nombre del autor
        SUM(IFNULL(m.VISITAS, 0)) AS total_visitas,        		
        SUM(IFNULL(m.COMPARTIR, 0)) AS total_compartir      		
    FROM TB_HECHOS h
    INNER JOIN TB_METADATOS m										-- unimos hechos con metadatos
        ON h.T_ID = m.T_ID                                    		
    LEFT JOIN DIM_AUTOR a
        ON h.ID_AUTOR = a.ID_AUTOR                                   		
    GROUP BY a.AUTOR                                         		-- agrupamos por autor
)
SELECT 
    'KPI 19 (Var)' AS KPI,
    AUTOR, total_visitas, total_compartir
FROM impacto_por_autor
ORDER BY total_visitas DESC, total_compartir DESC, AUTOR ASC;



## KPI 20: Para cada texto, calcular la relación entre la longitud del título y la longitud del texto. 
-- Responsable: Ivette
-- Fuente: TB_HECHOS
-- Definición: Ratio entre longitud del título y el texto de cada noticia
							
SELECT 
    'KPI 20' AS KPI,
    T_ID,
    TITULO,
    CHAR_LENGTH(TITULO) AS longitud_titulo,
    CHAR_LENGTH(TEXTO) AS longitud_texto,
    -- Calculo del ratio evitando operación indefinida al dividir por cero
    ROUND((CHAR_LENGTH(TITULO) / NULLIF(CHAR_LENGTH(TEXTO), 0)), 4) AS ratio_titulo_texto
FROM 
    TB_HECHOS
ORDER BY 
    ratio_titulo_texto DESC;