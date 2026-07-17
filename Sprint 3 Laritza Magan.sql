/*=========================================================
  NIVEL 1
  
  Ejercicio 1

  Dataset Bronze:
  Creado mediante la Interfase gráfica (UI).

  Dataset Silver:
  Creado con SQL (CREATE SCHEMA).

  Dataset Gold:
  Creado mediante Cloud Shell con la comanda:
  bq mk --dataset --location=EU sprint3_gold
=========================================================*/

CREATE SCHEMA `sprint3-analytics-laritza.sprint3_silver`
OPTIONS (
    location = 'EU'
);

/*=========================================================

Ejercicio 2

Crear tabla externa en el dataset Bronze, con los datos de la tabla transactions.csv,
ubicada en el bucket de GCS bootcamp-data-analytics-public/ERP.

=========================================================*/

CREATE EXTERNAL TABLE `sprint3-analytics-laritza.sprint3_bronze.transactions_raw` 

OPTIONS(
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
    field_delimiter = ';',
    skip_leading_rows = 1
  );

  

-- ==========================================================
-- Ejercicio 3
-- La tabla nativa products_raw se ha creado mediante la opción
-- "Upload" de la interfaz gráfica de BigQuery, tal y como
-- especifica el enunciado. Por este motivo, en este ejercicio
-- no se ha utilizado código SQL.
-- ==========================================================



/*=========================================================

Ejercicio 4

Crea una tabla nueva llamada sprint3_bronze.transactions_raw_native que sea una copia exacta de tu tabla externa transactions_raw.
El script que sugiere Cloud Assist es el que figura mas abajo. El ejercicio pide veriricar si es correcto.

=========================================================*/

CREATE OR REPLACE TABLE `sprint3-analytics-laritza.sprint3_bronze.transactions_raw_native`
AS
SELECT * FROM `sprint3-analytics-laritza.sprint3_bronze.transactions_raw`


/*=========================================================

Ejercicio 5

Tu jefe quiere saber cuáles fueron los 5 días con mayores ingresos del año 2021.
Probablemente el campo timestamp sea un STRING. 
Tendrás que investigar funciones de BigQuery (SUBSTR, CAST, PARSE_TIMESTAMP) para filtrar el año y agruparlo por fecha correctamente.

=========================================================*/

-- Primero hago una comprobación de los datos en la tabla nativa 
-- para ver el formato del campo timestamp (y ver si usamos la función PARSE_TIMESTAMP o no).
-- Adicionalmente, en BigQuery, veo el esquema de la tabla y ahí puedo asegurar si es STRING o ya es TIMESTAMP.

SELECT timestamp
FROM `sprint3-analytics-laritza.sprint3_bronze.transactions_raw_native`
LIMIT 5;

SELECT
  timestamp,
  TYPEOF(timestamp) AS tipo_timestamp
FROM `sprint3-analytics-laritza.sprint3_bronze.transactions_raw_native`
LIMIT 5;



SELECT DATE(timestamp) AS fecha, ROUND(SUM(amount),2) AS ingresos
FROM `sprint3-analytics-laritza.sprint3_bronze.transactions_raw_native` 
WHERE EXTRACT(YEAR FROM timestamp) = 2021 
GROUP BY fecha
ORDER BY ingresos DESC
LIMIT 5;



/*=========================================================

Ejercicio 6

Necesitamos un informe que cruce datos. La tarea es:
Lista el nombre, país y fecha de las transacciones realizadas por empresas que realizaron operaciones entre 100 y 200 euros en alguna de estas fechas: 
29-04-2015,  20-07-2018 o 13-03-2024.

=========================================================*/

SELECT c.company_name, c.country, DATE(t.timestamp) AS fecha_transaccion
FROM `sprint3-analytics-laritza.sprint3_bronze.companies_raw` AS c
JOIN `sprint3-analytics-laritza.sprint3_bronze.transactions_raw` AS t
ON c.company_id = t.business_id
WHERE t.amount BETWEEN 100 AND 200
AND DATE(t.timestamp) IN (
    DATE '2015-04-29', DATE '2018-07-20', DATE '2024-03-13')
AND t.declined = 0;

-- Al hacer la consulta, surge un error. Big Query indica que no puede procesarla porque la tabla companies_raw, en alguna fila,
-- no tiene 8 columnas, sino 6.
-- Entonces realizamos una recreación:

CREATE OR REPLACE EXTERNAL TABLE
`sprint3-analytics-laritza.sprint3_bronze.companies_raw`
(
    company_id STRING,
    company_name STRING,
    phone STRING,
    email STRING,
    country STRING,
    website STRING,
    merchant_category STRING,
    merchant_price_position STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
    skip_leading_rows = 1,
    allow_jagged_rows = TRUE
);

-- Volvemos a ejecutar la consulta y ahora sí funciona correctamente.



/*=========================================================
  NIVEL 2
  
  Ejercicio 1

  Crearemos la capa limpia ("Silver") para los productos. Tienes la tabla sprint3_bronze.products_raw cargada desde el CSV. El equipo de Data Governance te pide crear una tabla de productos limpia en sprint3_silver.products_clean que cumpla estas reglas de calidad:
» Estandarización de Nombres: La columna original id es ambigua; renombrarla a product_id. La columna product_name simplifícala a name.
» Limpieza de IDs: El campo warehouse_id tiene el formato antiguo "WH-4". Elimina el prefijo "WH-" y convierte el valor en número entero (INT64).
» Garantía de Precio: Asegúrate de que price es un número (FLOAT64), sin símbolos de moneda.
» Otras columnas: Conserva el campo weight (peso) tal cual.

=========================================================*/

SELECT * 
FROM `sprint3_bronze.products_raw`
LIMIT 3;


CREATE OR REPLACE TABLE sprint3_silver.products_clean AS

SELECT
  id AS product_id,
  product_name AS name,
  price,
  colour,
  weight,
  CAST(REPLACE(warehouse_id,'WH-','') AS INT64) AS warehouse_id,
  category,
  brand,
  cost,
  launch_date
  
FROM sprint3_bronze.products_raw;


SELECT *
FROM sprint3_silver.products_clean
LIMIT 10;

/*=========================================================

Ejercicio 2
Creación de Transacciones Limpias

Escenari:
La taula transactions_raw (Bronze) és insegura: l'import (amount) podria tenir lletres, les coordenades podrien fallar i la data és un text difícil de filtrar. Crearem la taula definitiva sprint3_silver.transactions_clean que garanteixi el següent.

» Estandardització de Noms: La columna original id és ambigua; reanomena-la a transaction_id. 
» Robustesa en Imports: Utilitza SAFE_CAST al camp amount. Si falla, substitueix-lo per 0 (usant IFNULL).
» Dates Reals: Converteix el camp timestamp (que és STRING) a tipus TIMESTAMP real.
» Coordenades: Assegura que lat i longitude siguin FLOAT64 (utilitza SAFE_CAST per seguretat).
»Desglose de Productos: Transforma la cadena de texto product_ids en un ARRAY de enteros.
 Input: "1, 2, 3" (String)
Output: [1, 2, 3] (Array/Lista de enteros)
» Resta de camps: Mantén-los igual.


=========================================================*/


CREATE OR REPLACE TABLE `sprint3_silver.transactions_clean` AS

SELECT 
  id AS transaction_id,
  card_id,
  business_id,
  timestamp,
  IFNULL(SAFE_CAST(amount AS FLOAT64),0) AS amount,
  declined,
  product_ids,
  user_id,
  SAFE_CAST(lat AS FLOAT64) AS lat,
  SAFE_CAST(longitude AS FLOAT64) AS longitude
FROM `sprint3_bronze.transactions_raw`;

--transformar product_ids a ARRAY<INT64>

CREATE OR REPLACE TABLE `sprint3_silver.transactions_clean` AS

SELECT 
  id AS transaction_id,
  card_id,
  business_id,
  timestamp,
  IFNULL(SAFE_CAST(amount AS FLOAT64),0) AS amount,
  declined,
  ARRAY(
    SELECT CAST(TRIM(product_id) AS INT64)
    FROM UNNEST(SPLIT(product_ids, ',')) AS product_id
) AS product_ids,
  user_id,
  SAFE_CAST(lat AS FLOAT64) AS lat,
  SAFE_CAST(longitude AS FLOAT64) AS longitude
FROM `sprint3_bronze.transactions_raw`;


/*=========================================================

Ejercicio 3
Unificación de Usuarios (UNION)
Tenemos a los usuarios fragmentados por región.
Tarea:
Crea la tabla sprint3_silver.users_combined. Utiliza UNION ALL para unificar a los usuarios de EE.UU. y Europa en una única lista maestra. 
Añade una columna calculada origin para saber de dónde vienen.
» Estandarización de Nombres: La columna original id es ambigua; renombrarla a user_id


=========================================================*/


CREATE OR REPLACE TABLE `sprint3-analytics-laritza.sprint3_silver.users_combined` AS

SELECT 
        id AS user_id,
        name,
        surname,
        phone,
        email,
        birth_date,
        country,
        city,
        postal_code,
        address,
        'USA' AS origin
FROM `sprint3-analytics-laritza.sprint3_bronze.american_users_raw`

UNION ALL

SELECT 
        id AS user_id,
        name,
        surname,
        phone,
        email,
        birth_date,
        country,
        city,
        postal_code,
        address,
        'Europe' AS origin
FROM `sprint3-analytics-laritza.sprint3_bronze.european_users_raw`;



/*=========================================================

Ejercicio 4: Materialización de Compañías y Tarjetas de Crédito

Escenario:
Para completar el modelo de datos en la capa Silver, nos faltan dos dimensiones clave que actualmente dependen de archivos CSV externos:
Compañías y Tarjetas de Crédito. No podemos depender de archivos sueltos para el análisis final. 
Debemos importar estos datos en tablas nativas (Silver) y aprovechar para corregir formatos.

Tareas:
» 1. Crea la tabla sprint3_silver.companies_clean. 
  Copia los datos tal cual, pero asegúrate de que sea una tabla nativa de BigQuery (no una vista externa).
» 2. Crea la tabla sprint3_silver.credit_cards_clean. 
  Copia los datos tal cual, pero asegúrate de que sea una tabla nativa de BigQuery (no una vista externa).

Si es necesario, renombrar el id según corresponda.

=========================================================*/

CREATE OR REPLACE TABLE
`sprint3-analytics-laritza.sprint3_silver.companies_clean` AS

SELECT
    company_id,
    company_name,
    phone,
    email,
    country,
    website,
    merchant_category,
    merchant_price_position
FROM `sprint3-analytics-laritza.sprint3_bronze.companies_raw`;


CREATE OR REPLACE TABLE
`sprint3-analytics-laritza.sprint3_silver.credit_cards_clean` AS

SELECT
    id AS card_id,
    user_id,
    iban,
    pan,
    pin,
    cvv,
    track1,
    track2,
    expiring_date
FROM `sprint3-analytics-laritza.sprint3_bronze.credit_cards_raw`;


/*=========================================================
NIVEL 3
  
Ejercicio 1

La Vista de Marketing (Lógica de Negocio)
Marketing necesita segmentar a los clientes corporativos, pero no saben hacer JOINs. Tu tarea es dejarles la información preparada.
Crea una vista llamada sprint3_gold.v_marketing_kpis que muestre la siguiente información para cada compañía:

» Nombre de la compañía, Teléfono y País (origen: companies_clean).
» Media de compra (AVG(amount) de transactions_clean).
» Clasificación de Cliente (Lógica):
Crea una columna calculada llamada client_tier.
Si la media de compra es superior a 260€, etiqueta como "Premium".
Si es igual o inferior, etiqueta como "Standard".

👉 Entrega:
Realiza una consulta SELECT* sobre tu nueva vista, ordenando los resultados para que aparezcan primero los clientes "Premium" y,
dentro de éstos, los que tengan mayor media de compra.

=========================================================*/


CREATE OR REPLACE VIEW
  `sprint3-analytics-laritza.sprint3_gold.v_marketing_kpis` AS

SELECT
  c.company_name,
  c.phone,
  c.country,
  ROUND(AVG(t.amount), 2) AS media_compra,
  CASE
    WHEN AVG(t.amount) > 260 THEN 'Premium'
    ELSE 'Standard'
  END AS client_tier
FROM `sprint3-analytics-laritza.sprint3_silver.companies_clean` AS c
JOIN `sprint3-analytics-laritza.sprint3_silver.transactions_clean` AS t
  ON c.company_id = t.business_id
WHERE t.declined = 0
GROUP BY
  c.company_id,
  c.company_name,
  c.phone,
  c.country;



/*=========================================================

Ejercicio 2: Ranking de Productos (La Potencia de los Arrays)

Escenario:
El equipo de ventas desea optimizar el catálogo. 
Necesitan un informe en la capa Gold que muestre el rendimiento real de cada producto. 
Gracias a tu buena ingeniería en la capa Silver, 
la tabla transactions_clean ya tiene los IDs de producto perfectamente organizados en una lista (Array). 
Ahora toca explotar esa estructura.

Objetivo:
Crea la tabla sprint3_gold.product_sales_ranking que contenga el inventario completo de productos y cuántas veces se ha vendido cada uno.

Requisitos del Informe:
» Detalle del Producto: Debe incluir product_id, name, price y color (vienen de la tabla products_clean).
» Métrica de negocio: Una nueva columna total_sold que cuente cuántas veces aparece este producto en las transacciones.
» Integridad: Deben aparecer todos los productos, incluso los que tienen 0 ventas (quizás es necesario descatalogarlos).

Pista Técnica:
» En transactions_clean, los productos están "encapsulados" dentro de un Array por cada transacción.
» Primero necesitarás "allanar" la tabla de transacciones usando UNNEST(product_ids) para poder contar los productos individualmente.
» Después, haz un cruce (LEFT JOIN) empezando por la tabla de productos para no perder aquellos que nunca se han vendido.

=========================================================*/

CREATE OR REPLACE TABLE
  `sprint3-analytics-laritza.sprint3_gold.product_sales_ranking` AS

SELECT
  p.product_id,
  p.name,
  p.price,
  p.colour AS color,
  COUNT(t.transaction_id) AS total_sold
FROM `sprint3-analytics-laritza.sprint3_silver.products_clean` AS p
LEFT JOIN `sprint3-analytics-laritza.sprint3_silver.transactions_clean` AS t
  ON p.product_id IN UNNEST(t.product_ids)
  AND t.declined = 0
GROUP BY
  p.product_id,
  p.name,
  p.price,
  p.colour; 


SELECT *
FROM `sprint3-analytics-laritza.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;

/*=========================================================

Ejercicio 3: Exportación de Resultados

Tu manager no tiene acceso a BigQuery y quiere el listado de "Top Productos" en un Excel para una reunión.
Tarea:
Exporta los datos de la tabla product_sales_ranking a Google Sheets o descarga el archivo CSV localmente.

Entrega:
Una captura de pantalla donde se vea el archivo abierto (Excel/Sheets) con los datos correctamente formateados.

=========================================================*/

--Hecho en Google Sheets, no se requiere código SQL para esta tarea, salvo una consulta especifica para obtener los datos de las 
--columnas que se desean exportar, como name y total sold.

SELECT name, total_sold
FROM `sprint3-analytics-laritza.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;
