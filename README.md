# 🪐 Proyecto Júpiter - Detección de Fake News

Pipeline de datos, NLP e IA generativa para clasificar noticias como `REAL` o `FAKE`. Cinco fases encadenadas: normalización de las fuentes JSON a un modelo relacional (3FN), ingesta en MySQL, análisis exploratorio y feature engineering, comparación de 17 modelos de Machine Learning y Deep Learning, y una solución de IA generativa (scoring con LLM + búsqueda semántica RAG). Los KPI de negocio se explotan en un cuadro de mando de Power BI.

Trabajo de fin de máster (PontIA, Data Analytics & Data Science).

---

## Estructura del repositorio

```text
Proyecto_Jupiter_Final/
├── datos_raw/                              # INPUT: los 8 .json de origen (los de más de 25 MB, en .zip)
├── datos_1FN/                              # Genera NB1: tablas planas en 1FN para NB3 (.parquet)
├── datos_3FN/                              # Genera NB1: modelo relacional en 3FN para NB2 (.csv)
├── datos_procesados/                       # Genera NB3: df_unificado.csv (consumido por NB4 y NB5)
├── descargas/                              # Genera NB3 y NB4: figuras y tablas de la comparativa
├── mysql/
│   ├── 1_Relacional.sql                    # Crea la base db_fake_news, dimensiones, hechos y metadatos
│   ├── 2_Comprobacion_ingesta.sql          # Valida volumetría, integridad referencial y duplicados
│   └── 3_KPI_Fake_News.sql                 # 20 KPI de negocio
├── Notebook_1_Normalizacion_dataset.ipynb  # Fase I: normalización
├── Notebook_2_Ingesta_MySQL.ipynb          # Fase II: ingesta relacional
├── Notebook_3_EDA.ipynb                    # Fase III: EDA y consolidación
├── Notebook_4_ML___DL.ipynb                # Fase IV: 17 modelos (ML y DL)
├── Notebook_5_IA_generativa.ipynb          # Fase V: IA generativa (scoring LLM + RAG con FAISS)
├── Dashboard_Jupiter.pbix                  # Cuadro de mando en Power BI
├── Memoria_Fake_News.pdf                   # Memoria técnica y de negocio
├── IA_generativa.pdf                       # Documento de la solución de IA generativa
└── requirements.txt
```

---

## Datos

Los datos son **ficticios** y se incluyen en el repositorio para poder reproducir el proyecto.

> ⚠️ **Antes de ejecutar los notebooks:** los ficheros de datos que superaban los 25 MB (algunos `.json` y `.csv`) se han subido **comprimidos en `.zip`** por el límite de tamaño de GitHub. Descomprime cada `.zip` **en la misma carpeta en la que está**, de modo que el fichero original quede en su ruta esperada (por ejemplo, `datos_raw/archivo.json`). Si no se descomprimen, los notebooks no encontrarán los datos.

Si prefieres regenerar los datos intermedios desde cero, basta con los 8 `.json` de `datos_raw/`: el resto de carpetas (`datos_1FN/`, `datos_3FN/`, `datos_procesados/`, `descargas/`) las generan los notebooks al ejecutarse.

---

## Requisitos

- **Python 3.10** (desarrollado en 3.10.11).
- **MySQL** local, solo para la rama relacional (Fase II). No es necesario para reproducir los resultados de ML.
- **Google Colab** para la Fase V (NB5): se ejecuta **exclusivamente en Colab**, no en local. Requiere además una **clave de API de OpenAI**, que el notebook lee de los **Secretos de Colab** (icono de llave 🔑, con el nombre `OPENAI_API_KEY`) y no se almacena en el repositorio.

### Entorno

```bash
python -m venv venv
# Windows
venv\Scripts\activate
# Linux / macOS
source venv/bin/activate

pip install -r requirements.txt
```

`requirements.txt` cubre las Fases I a IV, que se ejecutan en local. La Fase V (NB5) corre en Google Colab e instala sus propias dependencias dentro del notebook.

---

## Ejecución

El orden es estricto por dependencias de ficheros y de claves foráneas. Hay dos ramas que parten de NB1:

- **Rama relacional (MySQL):** pasos 2 a 5 y el dashboard (9). Opcional; solo si se quiere la base de datos, los KPI y el cuadro de mando.
- **Rama analítica (ML e IA):** pasos 6 a 8. Suficiente para reproducir el modelado y la IA generativa.

| # | Acción | Entrada | Salida |
|---|--------|---------|--------|
| 1 | **NB1 - Normalización** | `datos_raw/` (8 JSON) | `datos_1FN/` (Parquet) y `datos_3FN/` (CSV) |
| 2 | **`mysql/1_Relacional.sql`** | — | Base `db_fake_news` con dimensiones, `TB_HECHOS` y `TB_METADATOS` |
| 3 | **NB2 - Ingesta MySQL** | `datos_3FN/` | Tablas cargadas (pide contraseña con `getpass`) |
| 4 | **`mysql/2_Comprobacion_ingesta.sql`** | Base cargada | Verificación: 6.335/6.335 registros, sin duplicados |
| 5 | **`mysql/3_KPI_Fake_News.sql`** | Base cargada | 20 KPI de negocio |
| 6 | **NB3 - EDA** | `datos_1FN/` | `datos_procesados/df_unificado.csv` (6.335 × 15) |
| 7 | **NB4 - Modelado** | `df_unificado.csv` | Métricas y comparativa de los 17 modelos |
| 8 | **NB5 - IA generativa** (Google Colab) | `df_unificado.csv` + clave OpenAI | Scoring de noticias e índice RAG (FAISS) |
| 9 | **Dashboard (Power BI)** | Base `db_fake_news` (MySQL) | `Dashboard_Jupiter.pbix`: cuadro de mando con los 20 KPI |

---

## Resultados

**Analítica de negocio (KPI).** 20 KPI resueltos con SQL sobre MySQL: distribución fake/real, tipos y fuentes con mayor proporción de noticias falsas, y patrones temporales de publicación y compartición. El reparto de clases es equilibrado (≈50/50) y las "Noticias de última hora" concentran la mayor proporción de fake. `Dashboard_Jupiter.pbix` los visualiza en Power BI.

**Modelado (NB4).** 17 modelos sobre tres representaciones del mismo corpus (tabular, TF-IDF, secuencias), bajo un protocolo común: partición estratificada, umbral 0,5, mismas métricas y `SEED = 42`. El resultado central: la representación decide el rendimiento, no el algoritmo. Los 10 modelos que usan solo metadatos tabulares se estancan en 0,65-0,69 de ROC-AUC; en cuanto el modelo accede al texto, sube a 0,84-0,99.

- Mejor discriminación: **CNN 1-D** (ROC-AUC ≈ 0,99).
- Recomendado para producción: **Regresión Logística sobre TF-IDF** (ROC-AUC ≈ 0,98), por interpretabilidad, simplicidad y despliegue sencillo, con rendimiento a un margen de la CNN.

**IA generativa (NB5).** Solución dual sobre el mismo dataset, con GPT-4o-mini, OpenAI Embeddings, FAISS y LangChain:
- **Scoring y justificación:** puntúa cada noticia y redacta el porqué de la alerta (moderación).
- **Asistente RAG:** indexa las 6.335 noticias en FAISS y responde consultas semánticas sobre el histórico (auditoría). Modelo operativo Human-in-the-Loop.

---

## Reproducibilidad

- Muestreo y partición gobernados por `SEED = 42`.
- Los modelos deterministas (Regresión Logística, K-NN, Naive Bayes, Árbol, SVM) reproducen cifras exactas; los que entrenan en paralelo y las redes tienen un no determinismo de bajo nivel que mueve el tercer o cuarto decimal entre corridas, por lo que las conclusiones se apoyan en el orden de magnitud.
- El boosting por histogramas usa `HistGradientBoosting` de scikit-learn; el entorno no incluye LightGBM ni XGBoost a propósito.
- La Fase V depende de la API de OpenAI: su salida no es determinista y requiere clave y cuota activas.
