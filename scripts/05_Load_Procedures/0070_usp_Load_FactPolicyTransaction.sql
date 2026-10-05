USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0070_usp_Load_FactPolicyTransaction.sql

Purpose:
	Populates the FactPolicyTransaction table by sourcing Cleaned.PolicyData table. 
----------------------------------------------------------------------------------------------------------------------------------------------
*/

create or alter procedure Curated.usp_LoadFactPolicyTransaction
	@batch_id int
as 
begin
	
	set nocount ON;
	set xact_abort ON;

	declare @validation_datetime datetime2(3) = getdate();
	declare @rows_inserted int = 0;


	-- Clear prior validation results
	-------------------------------------------------------------------------------------------
	delete from Ctl.LoadValidationError
	where BatchID = @batch_id
		and ValidationStage = 'CleanedToCurated'
		and EntityName = 'PolicyTransaction'


	-- Validate batch exists in Cleaned.PolicyData
	-------------------------------------------------------------------------------------------
	if not exists
    (
        select 1

        from Cleaned.PolicyData

        where batch_id = @batch_id
    )
    begin
        insert into Ctl.LoadValidationError
        (
			BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
			,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
			,ValidationType, Severity, ErrorMessage, ValidationDatetime
        )
        values
        (
             @batch_id
            ,'CleanedToCurated'
            ,'PolicyTransaction'
            ,null
            ,null
            ,null
            ,null
            ,null
            ,'FPT_BATCH_001'
            ,'Batch Validation'
            ,'Error'
            ,'No Cleaned Policy rows were found for the supplied batch_id.'
            ,@validation_datetime
        );
    end;


    -- Validate policy lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'policy_id'
        ,cp.policy_id
        ,'FPT_DIM_001'
        ,'Dimension Lookup'
        ,'Error'
        ,'policy_id could not be resolved to Curated.DimPolicy.'
        ,@validation_datetime
    from Cleaned.PolicyData cp
    
    left join Curated.DimPolicy dp
        on dp.PolicyID = cp.policy_id

    where cp.batch_id = @batch_id
        and dp.PolicyKey is null;


    -- Validate Program lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'program_name'
        ,cp.program_name
        ,'FPT_DIM_002'
        ,'Dimension Lookup'
        ,'Error'
        ,'program_name could not be resolved to Curated.DimProgram.'
        ,@validation_datetime
    from Cleaned.PolicyData cp
    left join Curated.DimProgram dp
        on dp.ProgramName = cp.[program_name]

    where cp.batch_id = @batch_id
        and dp.ProgramKey is null;


    -- Validate Policyholder lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'policyholder_id'
        ,cp.policyholder_id
        ,'FPT_DIM_003'
        ,'Dimension Lookup'
        ,'Error'
        ,'policyholder_id could not be resolved to Curated.DimPolicyholder.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimPolicyholder dph
        on dph.PolicyholderID = cp.policyholder_id

    where cp.batch_id = @batch_id
      and dph.PolicyholderKey is null;


    --Validate Carrier lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'carrier_company_name'
        ,cp.carrier_company_name
        ,'FPT_DIM_004'
        ,'Dimension Lookup'
        ,'Error'
        ,'carrier_company_name could not be resolved to Curated.DimCarrier.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimCarrier dc
        on dc.CarrierName = cp.carrier_company_name

    where cp.batch_id = @batch_id
      and dc.CarrierKey is null;


    -- Validate Agency lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'agency_name'
        ,cp.agency_name
        ,'FPT_DIM_005'
        ,'Dimension Lookup'
        ,'Error'
        ,'agency_name could not be resolved to Curated.DimAgency.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimAgency da
        on da.AgencyName = cp.agency_name

    where cp.batch_id = @batch_id
      and da.AgencyKey is null;


    -- Validate Geography lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'state'
        ,cp.[state]
        ,'FPT_DIM_006'
        ,'Dimension Lookup'
        ,'Error'
        ,'state could not be resolved to Curated.DimGeography.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimGeography dg
        on dg.StateCode = cp.[state]

    where cp.batch_id = @batch_id
      and dg.GeographyKey is null;


    -- Validate EffectiveDate lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'effective_date'
        ,convert(varchar(10), cp.effective_date, 23)
        ,'FPT_DATE_001'
        ,'Dimension Lookup'
        ,'Error'
        ,'effective_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimDate dd
        on dd.FullDate = cp.effective_date

    where cp.batch_id = @batch_id
      and dd.DateKey is null;


    -- Validate ExpirationDate lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'expiration_date'
        ,convert(varchar(10), cp.expiration_date, 23)
        ,'FPT_DATE_002'
        ,'Dimension Lookup'
        ,'Error'
        ,'expiration_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimDate dd
        on dd.FullDate = cp.expiration_date

    where cp.batch_id = @batch_id
      and dd.DateKey is null;


    -- Validate SourceDate lookup
    -------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'source_date'
        ,convert(varchar(10), cp.source_date, 23)
        ,'FPT_DATE_003'
        ,'Dimension Lookup'
        ,'Error'
        ,'source_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from Cleaned.PolicyData cp

    left join Curated.DimDate dd
        on dd.FullDate = cp.source_date

    where cp.batch_id = @batch_id
      and dd.DateKey is null;


    -- Validate transaction is not already loaded
    ------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
        ,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
        ,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         cp.batch_id
        ,'CleanedToCurated'
        ,'PolicyTransaction'
        ,null
        ,cp.source_file_name
        ,cp.policy_transaction_id
        ,'policy_transaction_id'
        ,cp.policy_transaction_id
        ,'FPT_DUP_001'
        ,'Duplicate Validation'
        ,'Error'
        ,'policy_transaction_id already exists in Curated.FactPolicyTransaction.'
        ,@validation_datetime
    from Cleaned.PolicyData cp
    where cp.batch_id = @batch_id
      and exists
      (
          select 1
          from Curated.FactPolicyTransaction fpt
          where fpt.PolicyTransactionID = cp.policy_transaction_id
      );


    -- Stops execution of script if validation errors exist; will return rather than throw
	-------------------------------------------------------------------------------------------
    if exists
    (
        select 1
        from Ctl.LoadValidationError
        where BatchID = @batch_id
          and ValidationStage = 'CleanedToCurated'
          and EntityName = 'PolicyTransaction'
          and Severity = 'Error'
    )
    begin
        -- Provide validation error summary
        select
             Severity
            ,ValidationCode
            ,ValidationType
            ,count(*) as ValidationCount
        from Ctl.LoadValidationError

        where BatchID = @batch_id
          and ValidationStage = 'CleanedToCurated'
          and EntityName = 'PolicyTransaction'

        group by
             Severity
            ,ValidationCode
            ,ValidationType

        order by ValidationCode;


        --Detailed validation results
        select
             ValidationErrorID
            ,BatchID
            ,SourceFileName
            ,RecordIdentifier
            ,ColumnName
            ,InvalidValue
            ,ValidationCode
            ,ValidationType
            ,Severity
            ,ErrorMessage
            ,ValidationDatetime
        from Ctl.LoadValidationError

        where BatchID = @batch_id
          and ValidationStage = 'CleanedToCurated'
          and EntityName = 'PolicyTransaction'

        order by
             RecordIdentifier
            ,ValidationCode;

        return;
    end;


    -- Load FactPolicyTransaction
    -------------------------------------------------------------------------------------------

    begin try

        begin transaction;

        insert into Curated.FactPolicyTransaction
        (
             PolicyTransactionID

            ,PolicyKey
            ,ProgramKey
            ,PolicyholderKey
            ,CarrierKey
            ,AgencyKey
            ,GeographyKey

            ,EffectiveDateKey
            ,ExpirationDateKey
            ,SourceDateKey

            ,TransactionType

            ,TotalPremium

            ,AgencyPremiumPercent
            ,AgencyPremiumAmount

            ,CarrierPremiumPercent
            ,CarrierPremiumAmount

            ,CedingPremiumPercent
            ,CedingPremiumAmount

            ,StatePremiumTaxPercent
            ,StatePremiumTaxAmount

            ,MCAREFeePercent
            ,MCAREFeeAmount

            ,PolicyFeePercent
            ,PolicyFeeAmount

            ,SurplusLinesTaxPercent
            ,SurplusLinesTaxAmount

            ,StampingFeePercent
            ,StampingFeeAmount

            ,BatchID
        )
        select
             cp.policy_transaction_id

            ,dp.PolicyKey
            ,dpr.ProgramKey
            ,dph.PolicyholderKey
            ,dc.CarrierKey
            ,da.AgencyKey
            ,dg.GeographyKey

            ,ded.DateKey
            ,dxd.DateKey
            ,dsd.DateKey

            ,cp.transaction_type

            ,cp.total_premium

            ,cp.[broker_premium_%]
            ,cp.broker_premium_$

            ,cp.[carrier_premium_%]
            ,cp.carrier_premium_$

            ,cp.[ceding_company_premium_%]
            ,cp.ceding_premium_$

            ,cp.[state_premium_tax_%]
            ,cp.state_premium_tax

            ,cp.[mcare_fee_%]
            ,cp.mcare_fee

            ,cp.[policy_fee_%]
            ,cp.policy_fee

            ,cp.[surplus_lines_tax_%]
            ,cp.surplus_lines_tax

            ,cp.[stamping_fee_%]
            ,cp.stamping_fee

            ,cp.batch_id
        from Cleaned.PolicyData cp

        inner join Curated.DimPolicy dp
            on dp.PolicyID = cp.policy_id
        inner join Curated.DimProgram dpr
            on dpr.ProgramName = cp.[program_name]
        inner join Curated.DimPolicyholder dph
            on dph.PolicyholderID = cp.policyholder_id
        inner join Curated.DimCarrier dc
            on dc.CarrierName = cp.carrier_company_name
        inner join Curated.DimAgency da
            on da.AgencyName = cp.agency_name
        inner join Curated.DimGeography dg
            on dg.StateCode = cp.[state]
        inner join Curated.DimDate ded
            on ded.FullDate = cp.effective_date
        inner join Curated.DimDate dxd
            on dxd.FullDate = cp.expiration_date
        inner join Curated.DimDate dsd
            on dsd.FullDate = cp.source_date

        where cp.batch_id = @batch_id;

        set @rows_inserted = @@ROWCOUNT;

        commit transaction;
    end try

    begin catch
        if @@TRANCOUNT > 0
            rollback transaction;

        throw;
    end catch;


    --Return load results
    -------------------------------------------------------------------------------------------

    select
         @batch_id as BatchID
        ,@rows_inserted as RowsInserted;
end;
go