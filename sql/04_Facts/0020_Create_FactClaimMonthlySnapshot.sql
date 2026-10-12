use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	02_Create_FactClaimMonthlySnapshot.sql

Purpose:
	Creates the Claim monthly snapshot fact table.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
if object_id('Curated.FactClaimMonthlySnapshot', 'U') is null
begin
    create table Curated.FactClaimMonthlySnapshot
    (
         ClaimSnapshotKey               bigint identity(1,1) not null

        ,ClaimID                        varchar(100) not null

        ,PolicyKey                      int not null
        ,ProgramKey                     int not null
        ,PolicyholderKey                int not null
        ,CarrierKey                     int not null
        ,GeographyKey                   int not null

        ,SnapshotDateKey                int not null
        ,LossDateKey                    int not null
        ,ReportedDateKey                int not null
        ,RecordDateKey                  int not null
        ,SourceDateKey                  int not null

        ,ClaimStatus                    varchar(50) not null
        ,DenialReason                   varchar(500) null

        ,IndemnityReserve               decimal(18,2) null
        ,IndemnityPaid                  decimal(18,2) null

        ,ALAEReserve                    decimal(18,2) null
        ,ALAEPaid                       decimal(18,2) null

        ,SalvageRecovery                decimal(18,2) null
        ,SubrogationRecovery            decimal(18,2) null
        ,DeductibleRecovery             decimal(18,2) null

        ,IndemnityReserveMovement       decimal(18,2) null
        ,IndemnityPaidMovement          decimal(18,2) null

        ,ALAEReserveMovement            decimal(18,2) null
        ,ALAEPaidMovement               decimal(18,2) null

        ,SalvageRecoveryMovement        decimal(18,2) null
        ,SubrogationRecoveryMovement    decimal(18,2) null
        ,DeductibleRecoveryMovement     decimal(18,2) null

        ,BatchID                        int not null

        ,constraint PK_FactClaimMonthlySnapshot
            primary key (ClaimSnapshotKey)

        ,constraint UQ_FactClaimMonthlySnapshot
            unique (ClaimID,SnapshotDateKey)

        ,constraint FK_FactClaimMonthlySnapshot_DimPolicy
            foreign key (PolicyKey)
            references Curated.DimPolicy (PolicyKey)

        ,constraint FK_FactClaimMonthlySnapshot_DimProgram
            foreign key (ProgramKey)
            references Curated.DimProgram (ProgramKey)

        ,constraint FK_FactClaimMonthlySnapshot_DimPolicyholder
            foreign key (PolicyholderKey)
            references Curated.DimPolicyholder (PolicyholderKey)

        ,constraint FK_FactClaimMonthlySnapshot_DimCarrier
            foreign key (CarrierKey)
            references Curated.DimCarrier (CarrierKey)

        ,constraint FK_FactClaimMonthlySnapshot_DimGeography
            foreign key (GeographyKey)
            references Curated.DimGeography (GeographyKey)

        ,constraint FK_FactClaimMonthlySnapshot_SnapshotDate
            foreign key (SnapshotDateKey)
            references Curated.DimDate (DateKey)

        ,constraint FK_FactClaimMonthlySnapshot_LossDate
            foreign key (LossDateKey)
            references Curated.DimDate (DateKey)

        ,constraint FK_FactClaimMonthlySnapshot_ReportedDate
            foreign key (ReportedDateKey)
            references Curated.DimDate (DateKey)

        ,constraint FK_FactClaimMonthlySnapshot_RecordDate
            foreign key (RecordDateKey)
            references Curated.DimDate (DateKey)

        ,constraint FK_FactClaimMonthlySnapshot_SourceDate
            foreign key (SourceDateKey)
            references Curated.DimDate (DateKey)
    );
end;
go