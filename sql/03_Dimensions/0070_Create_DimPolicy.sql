use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	07_Create_DimPolicy.sql

Purpose:
	Creates Policy dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Curated.DimPolicy','U') is null
begin
	create table Curated.DimPolicy
	(
		PolicyKey			int identity(1,1)	not null
		,PolicyID			varchar(50)			not null
		,CoreAccountNumber	varchar(20)			not null
		,PolicyType			varchar(100)		not null
		,CoverageBasis		varchar(30)			not null

		,EffectiveDate		date				not null
		,ExpirationDate		date				not null
		,RetroactiveDate	date				null

		,OccuranceLimit		decimal(18,2)		null
		,AggregateLimit		decimal(18,2)		null
		
		,RetentionType		varchar(20)			null
		,DeductibleAmount	decimal(18,2)		null
		,SIRAmount			decimal(18,2)		null

		,TreatyYear			int					not null
		,RenewalSequence	int					not null

		constraint PK_DimPolicy
			primary key (PolicyKey),

		constraint UQ_DimPolicy_PolicyID
			unique (PolicyID)
	)
end


-- Insert unknown policy value with 0 key
if not exists
(
	select 1
	from Curated.DimPolicy
	where PolicyKey = 0
)
begin
	set identity_insert Curated.DimPolicy ON;

	insert into Curated.DimPolicy
	(
	PolicyKey,PolicyID,CoreAccountNumber,PolicyType,CoverageBasis		
	,EffectiveDate,ExpirationDate,RetroactiveDate
	,OccuranceLimit,AggregateLimit		
	,RetentionType,DeductibleAmount,SIRAmount			
	,TreatyYear,RenewalSequence	
	)
	values
	(
		0,'Unknown','Unknown','Unknown','Unknown'
		,'9999-12-31','9999-12-31',NULL
		,NULL,NULL
		,NULL,NULL,NULL
		,'9999','9999'
	)

	set identity_insert Curated.DimPolicy OFF;
end