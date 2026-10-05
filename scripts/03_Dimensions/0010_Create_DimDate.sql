use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	01_Create_DimDate.sql

Purpose:
	Creates Date dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
IF OBJECT_ID('Curated.DimDate','U') IS NULL
BEGIN
	CREATE TABLE Curated.DimDate
	(
		DateKey			int				not null
		,FullDate		date			not null
		,[DayofMonth]	int				not null
		,[DayName]		varchar(10)		not null
		,MonthNumber	int				not null
		,[MonthName]	varchar(10)		not null
		,QuarterNumber	int				not null
		,[Year]			int				not null
		,YearMonth		char(7)			not null

		CONSTRAINT PK_DimDate
			PRIMARY KEY (DateKey)

		,CONSTRAINT UQ_DimDate_FullDate
			UNIQUE (FullDate)
	);
END
GO
