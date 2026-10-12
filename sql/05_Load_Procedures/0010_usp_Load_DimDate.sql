use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0010_usp_Load_DimDate.sql

Purpose:
	Populates Date dimension with date range.

----------------------------------------------------------------------------------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE Curated.usp_LoadDimDate
	@StartDate date,
	@EndDate date
AS
BEGIN

--DECLARE @StartDate	date = '2020-01-01';
--DECLARE @EndDate	date = '2035-12-31';


WITH DateSeries AS 
(
	SELECT @StartDate AS FullDate

	UNION ALL

	SELECT DATEADD(Day,1,FullDate)
	FROM DateSeries
	WHERE FullDate < @EndDate
)
INSERT INTO Curated.DimDate
(
	DateKey			
	,FullDate		
	,[DayofMonth]	
	,[DayName]		
	,MonthNumber	
	,[MonthName]	
	,QuarterNumber	
	,[Year]			
	,YearMonth		
)
SELECT
	YEAR(FullDate) * 10000 
		+ MONTH(FullDate) * 100
		+ DAY(FullDate)					AS DateKey

,FullDate
,DAY(FullDate)							AS [DayofMonth]
,DATENAME(WEEKDAY,FullDate)				AS [DayName]
,MONTH(FullDate)						AS MonthNumber
,DATENAME(MONTH,FullDate)				AS [MonthName]
,DATEPART(QUARTER,FullDate)				AS QuarterName
,YEAR(FullDate)							AS [Year]
,CONVERT(Char(7),FullDate,126)			AS YearMonth
FROM DateSeries
WHERE NOT EXISTS
(
    SELECT 1
    FROM Curated.DimDate AS d
    WHERE d.FullDate = DateSeries.FullDate
)
OPTION (MAXRECURSION 0);

END;
GO