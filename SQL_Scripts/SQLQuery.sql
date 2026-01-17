
--¿Qué productos generan más ingresos? (Pregunta mas concreta solo se necesita un query)

select [Product ID],[Product Name],sum([Sales])as sum_sales from [Sample - Superstore]
group by [Product ID],[Product Name]
order by sum([Sales]) desc

--¿Dónde se pierde rentabilidad? (Pregunta mas gerneral se necesitar ver distintos ecenarios)

	--¿Producto con mas perdidas?
select top 5 [Product ID],[Product Name],sum([Profit])as sum_profit from [Sample - Superstore]
group by [Product ID],[Product Name],[Segment]
order by sum([Profit]) asc

	--¿Categoria de producto con mas perdidas?
SELECT 
    [Category], 
    [Sub-Category], 
    SUM([Sales]) AS Total_Sales, 
    SUM([Profit]) AS Total_Profit,
    (SUM([Profit]) / SUM([Sales])) * 100 AS Porcentaje_Ganancias
FROM [Sample - Superstore]
GROUP BY [Category], [Sub-Category]
HAVING SUM([Profit]) < 0  -- Solo los que dan pérdida
ORDER BY Total_Profit ASC;

	--¿Cuales son los estados con mas perdidas?
WITH RegionLoss AS (
    SELECT 
        [Region], 
        [State], 
        SUM([Profit]) AS State_Profit,
        COUNT([Order ID]) AS Total_Orders
    FROM [Sample - Superstore]
    GROUP BY [Region], [State]
)
SELECT * FROM RegionLoss
WHERE State_Profit < 0
ORDER BY State_Profit ASC;

SELECT 
    [Product Name], 
    AVG([Discount]) AS Promedio_Descuento, 
    SUM([Profit]) AS Total_Profit
FROM [Sample - Superstore]
GROUP BY [Product Name]
HAVING SUM([Profit]) < -2000
ORDER BY Total_Profit asc;

--¿Qué clientes son más valiosos?

SELECT TOP 10
    [Customer ID], 
    [Customer Name], 
    SUM([Sales]) AS Total_Sales,
    SUM([Profit]) AS Total_Profit
FROM [Sample - Superstore]
GROUP BY [Customer ID], [Customer Name]
ORDER BY Total_Profit DESC;

select top 10 [Customer ID], 
    [Customer Name], 
    SUM([Sales]) AS Total_Sales,
	 SUM([Profit]) AS Total_Profit
	FROM [Sample - Superstore]
GROUP BY [Customer ID], [Customer Name]
ORDER BY Total_Sales DESC;


--Ventas mensuales por región
SELECT 
    [Region], 
    MONTH([Order Date]) AS Mes, 
    YEAR([Order Date]) AS Anio, 
    SUM([Sales]) AS Ventas_Mensuales
FROM [Sample - Superstore]
GROUP BY [Region], YEAR([Order Date]), MONTH([Order Date])
ORDER BY Anio, Mes, [Region];

--Top 10 productos
SELECT TOP 10
    [Product ID], 
    [Product Name], 
    SUM([Sales]) AS Total_Sales,
    SUM([Profit]) AS Total_Profit
FROM [Sample - Superstore]
GROUP BY [Product ID], [Product Name]
ORDER BY Total_Profit DESC;

--Clientes con mayor margen
SELECT TOP 10
    [Customer Name],
    SUM([Sales]) AS Total_Sales,
    SUM([Profit]) AS Total_Profit,
    (SUM([Profit]) / SUM([Sales])) * 100 AS Margin_Percent
FROM [Sample - Superstore]
GROUP BY [Customer Name]
HAVING SUM([Sales]) > 500 -- Filtro para evitar clientes de una sola compra pequeña
ORDER BY Margin_Percent DESC;
--Comparativo año vs año

SELECT 
    YEAR([Order Date]) AS Year,
    SUM([Sales]) AS Annual_Sales,
    LAG(SUM([Sales])) OVER (ORDER BY YEAR([Order Date])) AS Last_Year_Sales,
    (SUM([Sales]) - LAG(SUM([Sales])) OVER (ORDER BY YEAR([Order Date]))) / LAG(SUM([Sales])) OVER (ORDER BY YEAR([Order Date])) * 100 AS Growth_Percent
FROM [Sample - Superstore]
GROUP BY YEAR([Order Date]);


--Limpiesa de datos

--ORDEN
--Paso 1 ingreesas datos en la tabla

	--TABLA PRODUCTO
	DROP TABLE DimProducto

SELECT [Product ID], MAX([Product Name]) as [Product Name], [Category], [Sub-Category]
INTO DimProducto
FROM [Sample - Superstore]
GROUP BY [Product ID], [Category], [Sub-Category];

ALTER TABLE DimProducto 
ALTER COLUMN [Product ID] nvarchar(255) NOT NULL;

ALTER TABLE DimProducto ADD PRIMARY KEY ([Product ID]);

	--TABLA CLIENTE
	DROP TABLE DimCliente
SELECT DISTINCT 
    [Customer ID], 
    [Customer Name], 
    [Segment]
INTO DimCliente
FROM [Sample - Superstore];

ALTER TABLE DimCliente 
ALTER COLUMN [Customer ID] nvarchar(255) NOT NULL;

ALTER TABLE DimCliente ADD PRIMARY KEY ([Customer ID]);

	--TABLA GEOGRAFIA
	DROP TABLE DimGeografia

CREATE TABLE DimGeografia (
    GeoKey INT IDENTITY(1,1) PRIMARY KEY, -- Esta es la nueva llave única
    [Postal Code] NVARCHAR(20),
    [City] NVARCHAR(255),
    [State] NVARCHAR(255),
    [Region] NVARCHAR(255),
    [Country] NVARCHAR(255)
);

-- Insertamos los datos ÚNICOS (pero ahora la combinación Postal+Ciudad es única)
INSERT INTO DimGeografia ([Postal Code], [City], [State], [Region], [Country])
SELECT DISTINCT [Postal Code], [City], [State], [Region], [Country]
FROM [Sample - Superstore];


	--TABLA Ventas
	DROP TABLE FactVentas
SELECT 
    [Row ID],        -- Tu referencia al CSV original
    [Order ID], 
    [Order Date], 
    [Customer ID], 
    [Product ID], 
    [Postal Code],
	[City],-- Usaremos este para unir con la Dimensión después
    [Sales], 
    [Profit]
INTO FactVentas
FROM [Sample - Superstore];

ALTER TABLE FactVentas 
ALTER COLUMN [Product ID] nvarchar(255) NOT NULL;

ALTER TABLE FactVentas ADD GeoKey INT;

UPDATE FV
SET FV.GeoKey = DG.GeoKey
FROM FactVentas FV
INNER JOIN DimGeografia DG 
    ON FV.[Postal Code] = DG.[Postal Code] 
    AND FV.[City] = DG.[City];


	-- Crear la tabla DimFecha
SELECT DISTINCT
    [Order Date] AS DateKey,
    YEAR([Order Date]) AS Anio,
    MONTH([Order Date]) AS Mes,
    DATENAME(MONTH, [Order Date]) AS NombreMes,
    DATEPART(QUARTER, [Order Date]) AS Trimestre,
    DATENAME(WEEKDAY, [Order Date]) AS DiaSemana
INTO DimFecha
FROM [Sample - Superstore];

-- Ponerle llave primaria
ALTER TABLE DimFecha ALTER COLUMN DateKey date NOT NULL; 
ALTER TABLE DimFecha ADD PRIMARY KEY (DateKey);

-- Enlazarla con FactVentas
ALTER TABLE FactVentas ADD CONSTRAINT FK_Fecha FOREIGN KEY ([Order Date]) REFERENCES DimFecha(DateKey);

-- 1. Asegurar que el tipo de dato sea igual
ALTER TABLE FactVentas ALTER COLUMN [Customer ID] nvarchar(255) NOT NULL;

-- 2. Crear la relación
ALTER TABLE FactVentas ADD CONSTRAINT FK_Cliente FOREIGN KEY ([Customer ID]) REFERENCES DimCliente([Customer ID]);

ALTER TABLE FactVentas ADD CONSTRAINT FK_Producto FOREIGN KEY ([Product ID]) REFERENCES DimProducto([Product ID]);

ALTER TABLE FactVentas ADD CONSTRAINT FK_Geografia FOREIGN KEY (GeoKey) REFERENCES DimGeografia(GeoKey);