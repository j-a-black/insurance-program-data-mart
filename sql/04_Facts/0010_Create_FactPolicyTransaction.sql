USE InsurancePrograms;
GO

use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	01_Create_FactPolicyTransaction.sql

Purpose:
	Creates Policy Transaction Fact table.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if OBJECT_ID('Curated.FactPolicyTransaction','U') is null
begin
	create table Curated.FactPolicyTransaction
	(
		PolicyTransactionKey		bigint identity(1,1)	not null
		,PolicyTransactionID		varchar(100)			not null
		
		,PolicyKey					int						not null
		,ProgramKey					int						not null
		,PolicyholderKey			int						not null
		,CarrierKey					int						not null
		,AgencyKey					int						not null
		,GeographyKey				int						not null
		
		,EffectiveDateKey			int						not null
		,ExpirationDateKey			int						not null
		,SourceDateKey				int						not null

		,TransactionType			varchar(100)			not null
		
		,TotalPremium				decimal(19,6)			not null
		
        ,AgencyPremiumPercent		decimal(9,6) null
        ,AgencyPremiumAmount		decimal(19,6) null

        ,CarrierPremiumPercent		decimal(9,6) null
        ,CarrierPremiumAmount		decimal(19,6) null

        ,CedingPremiumPercent		decimal(9,6) null
        ,CedingPremiumAmount		decimal(19,6) null

        ,StatePremiumTaxPercent		decimal(9,6) null
        ,StatePremiumTaxAmount		decimal(19,6) null

        ,MCAREFeePercent			decimal(9,6) null
        ,MCAREFeeAmount				decimal(19,6) null

        ,PolicyFeePercent			decimal(9,6) null
        ,PolicyFeeAmount			decimal(19,6) null

        ,SurplusLinesTaxPercent		decimal(9,6) null
        ,SurplusLinesTaxAmount		decimal(19,6) null

        ,StampingFeePercent			decimal(9,6) null
        ,StampingFeeAmount			decimal(19,6) null

        ,BatchID					int not null

		constraint PK_FactPolicyTransaction
			primary key (PolicyTransactionKey),

		constraint UQ_FactPolicyTransaction_PolicyTransactionID
			unique (PolicyTransactionID),

		constraint FK_FactPolicyTransaction_DimPolicy
			foreign key (PolicyKey)
			references Curated.DimPolicy (PolicyKey),

		constraint FK_FactPolicyTransaction_DimProgram
			foreign key (ProgramKey)
			references Curated.DimProgram (ProgramKey),

		constraint FK_FactPolicyTransaction_DimPolicyholder
			foreign key (PolicyholderKey)
			references Curated.DimPolicyholder (PolicyholderKey),

		constraint FK_FactPolicyTransaction_DimCarrier
			foreign key (CarrierKey)
			references Curated.DimCarrier (CarrierKey),

		constraint FK_FactPolicyTransaction_DimAgency
			foreign key (AgencyKey)
			references Curated.DimAgency (AgencyKey),

		constraint FK_FactPolicyTransaction_DimGeography
			foreign key (GeographyKey)
			references Curated.DimGeography (GeographyKey),

		constraint FK_FactPolicyTransaction_EffectiveDate
			foreign key (EffectiveDateKey)
			references Curated.DimDate (DateKey),

		constraint FK_FactPolicyTransaction_ExpirationDate
			foreign key (ExpirationDateKey)
			references Curated.DimDate (DateKey),

		constraint FK_FactPolicyTransaction_SourceDate
			foreign key (SourceDateKey)
			references Curated.DimDate (DateKey)
	);
end