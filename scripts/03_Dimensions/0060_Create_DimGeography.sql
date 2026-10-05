use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	06_Create_DimGeography.sql

Purpose:
	Creates Geography dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Curated.DimGeography','U') is null
begin
	create table Curated.DimGeography
	(
		GeographyKey		int identity(1,1)	not null
		,StateCode			varchar(2)			not null
		,StateName			varchar(100)		not null

		constraint PK_DimGeography
			primary key (GeographyKey),

		constraint UQ_DimGeography_StateCode
			unique (StateCode),

		constraint UQ_DimGeography_StateName
			unique (StateName)
	);
end


-- Insert unknown geography value with 0 key
if not exists
(
	select 1
	from Curated.DimGeography
	where GeographyKey = 0
)
begin
	set identity_insert Curated.DimGeography ON;

	insert into Curated.DimGeography
	(GeographyKey,StateCode,StateName)
	values
	(0,'99','Unknown')

	set identity_insert Curated.DimGeography OFF;
end