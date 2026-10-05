use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	04_Create_DimCarrier.sql

Purpose:
	Creates Carrier dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Curated.DimCarrier','U') is null
BEGIN
	create table Curated.DimCarrier
	(
		CarrierKey		int identity(1,1)	not null
		,CarrierName	varchar(200)		not null

		constraint PK_DimCarrier
			primary key (CarrierKey),

		constraint UQ_DimCarrier_CarrierName
			unique (CarrierName)
	);
END


-- Insert unknown carrier value with 0 key
if not exists
(
	select 1
	from Curated.DimCarrier
	where CarrierKey = 0
)
BEGIN
	set identity_insert Curated.DimCarrier ON;

	insert into Curated.DimCarrier
	(CarrierKey,CarrierName)
	values
	(0,'Unknown')

	set identity_insert Curated.DimCarrier OFF;
END