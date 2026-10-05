use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	03_Create_DimPolicyholder.sql

Purpose:
	Creates Policyholder dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
IF OBJECT_ID('Curated.DimPolicyholder','U') IS NULL
BEGIN
	create table Curated.DimPolicyholder
	(
		PolicyholderKey		int	identity(1,1)	not null
		,PolicyholderID		varchar(30)			not null
		,PolicyholderName	varchar(200)		not null
		,NAICSCode			varchar(6)			not null

		constraint PK_DimPolicyholder
			primary key (PolicyholderKey),

		constraint UQ_DimPolicyholder_PolicyholderID
			unique (PolicyholderID)
);
END


-- Insert unknown policyholder value with 0 key
if not exists
(
	select 1
	from Curated.DimPolicyholder
	where PolicyholderKey = 0
)
BEGIN
	set identity_insert Curated.DimPolicyholder ON;

	insert into Curated.DimPolicyholder
	(PolicyholderKey,PolicyholderID,PolicyholderName,NAICSCode)
	values
	(0,'Unknown','Unknown','999999')

	set identity_insert Curated.DimPolicyholder OFF;
END
