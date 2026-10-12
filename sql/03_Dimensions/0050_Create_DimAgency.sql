use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	05_Create_DimAgency.sql

Purpose:
	Creates Agency dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Curated.DimAgency','U') is null
BEGIN
	create table Curated.DimAgency
	(
		AgencyKey		int identity(1,1)	not null
		,AgencyName		varchar(200)		not null

		constraint PK_DimAgency
			primary key (AgencyKey),

		constraint UQ_DimAgency_AgencyName
			unique (AgencyName)
	)
END


-- Insert unknown agency value with 0 key
if not exists
(
	select 1
	from Curated.DimAgency
	where AgencyKey = 0
)
begin
	set identity_insert Curated.DimAgency ON;

	insert into Curated.DimAgency
	(AgencyKey,AgencyName)
	values
	(0,'Unknown');

	set identity_insert Curated.DimAgency OFF;
end