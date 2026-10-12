use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0080_usp_Load_FactClaimMonthlySnapshot.sql

Purpose:
	Loads the Claim monthly snapshot fact table.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


create or alter procedure Curated.usp_LoadFactClaimMonthlySnapshot
     @batch_id int
as
begin

    set nocount on;
    set xact_abort on;


    declare @validation_datetime datetime2(3) = getdate();
    declare @rows_inserted int = 0;


    -- Clear prior validation results
	-------------------------------------------------------------------------------------------
    delete from Ctl.LoadValidationError

    where BatchID = @batch_id
      and ValidationStage = 'CleanedToCurated'
      and EntityName = 'ClaimMonthlySnapshot';


    -- Validate batch exists in Cleaned.PolicyData
	-------------------------------------------------------------------------------------------
    if not exists
    (
        select 1
        from Cleaned.ClaimsData
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
            ,'ClaimMonthlySnapshot'
            ,null
            ,null
            ,null
            ,null
            ,null
            ,'FCM_BATCH_001'
            ,'Batch Validation'
            ,'Error'
            ,'No Cleaned Claims rows were found for the supplied batch_id.'
            ,@validation_datetime
        );
    end;


    -- Create current monthly snapshot source
	-------------------------------------------------------------------------------------------
    drop table if exists #MonthlyClaims;


    with RankedClaims as
    (
        select
             c.claim_id
            ,c.policy_id
            ,c.policyholder_id
            ,c.[program_name]
            ,c.carrier_company_name

            ,c.loss_date
            ,c.reported_date
            ,c.record_date
            ,c.reporting_month
            ,c.source_date

            ,eomonth
            (convert(date, concat(c.reporting_month, '-01'), 23)
            ) as SnapshotDate

            ,c.claim_status
            ,c.[state]
            ,c.denial_reason

            ,c.indemnity_reserve
            ,c.indemnity_paid

            ,c.alae_reserve
            ,c.alae_paid

            ,c.salvage_recovery
            ,c.subrogation_recovery
            ,c.deductible_recovery

            ,c.source_file_name
            ,c.batch_id

            ,row_number() over 
            (partition by c.claim_id, c.reporting_month 
            order by c.record_date desc, c.source_date desc
            ) as RowNum

        from Cleaned.ClaimsData c
        where c.batch_id = @batch_id
    )

    select
         claim_id
        ,policy_id
        ,policyholder_id
        ,[program_name]
        ,carrier_company_name

        ,loss_date
        ,reported_date
        ,record_date
        ,reporting_month
        ,SnapshotDate
        ,source_date

        ,claim_status
        ,[state]
        ,denial_reason

        ,indemnity_reserve
        ,indemnity_paid

        ,alae_reserve
        ,alae_paid

        ,salvage_recovery
        ,subrogation_recovery
        ,deductible_recovery

        ,source_file_name
        ,batch_id

    into #MonthlyClaims
    from RankedClaims
    where RowNum = 1;


    -- Validate Policy lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'policy_id'
        ,mc.policy_id
        ,'FCM_DIM_001'
        ,'Dimension Lookup'
        ,'Error'
        ,'policy_id could not be resolved to Curated.DimPolicy.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimPolicy dp
        on dp.PolicyID = mc.policy_id

    where dp.PolicyKey is null;


    -- Validate Program lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'program_name'
        ,mc.[program_name]
        ,'FCM_DIM_002'
        ,'Dimension Lookup'
        ,'Error'
        ,'program_name could not be resolved to Curated.DimProgram.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimProgram dp
        on dp.ProgramName = mc.[program_name]

    where dp.ProgramKey is null;


    -- Validate Policyholder lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'policyholder_id'
        ,mc.policyholder_id
        ,'FCM_DIM_003'
        ,'Dimension Lookup'
        ,'Error'
        ,'policyholder_id could not be resolved to Curated.DimPolicyholder.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimPolicyholder dph
        on dph.PolicyholderID = mc.policyholder_id

    where dph.PolicyholderKey is null;


    -- Validate Carrier lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'carrier_company_name'
        ,mc.carrier_company_name
        ,'FCM_DIM_004'
        ,'Dimension Lookup'
        ,'Error'
        ,'carrier_company_name could not be resolved to Curated.DimCarrier.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimCarrier dc
        on dc.CarrierName = mc.carrier_company_name

    where dc.CarrierKey is null;


    -- Validate Geography lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'state'
        ,mc.[state]
        ,'FCM_DIM_005'
        ,'Dimension Lookup'
        ,'Error'
        ,'state could not be resolved to Curated.DimGeography.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimGeography dg
        on dg.StateCode = mc.[state]

    where dg.GeographyKey is null;


    -- Validate Snapshot lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'SnapshotDate'
        ,convert(varchar(10), mc.SnapshotDate, 23)
        ,'FCM_DATE_001'
        ,'Dimension Lookup'
        ,'Error'
        ,'SnapshotDate could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimDate dd
        on dd.FullDate = mc.SnapshotDate

    where dd.DateKey is null;


    -- Validate LossDate lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'loss_date'
        ,convert(varchar(10), mc.loss_date, 23)
        ,'FCM_DATE_002'
        ,'Dimension Lookup'
        ,'Error'
        ,'loss_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimDate dd
        on dd.FullDate = mc.loss_date

    where dd.DateKey is null;


    -- Validate ReportedDate lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'reported_date'
        ,convert(varchar(10), mc.reported_date, 23)
        ,'FCM_DATE_003'
        ,'Dimension Lookup'
        ,'Error'
        ,'reported_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimDate dd
        on dd.FullDate = mc.reported_date

    where dd.DateKey is null;


    -- Validate RecordDate lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'record_date'
        ,convert(varchar(10), mc.record_date, 23)
        ,'FCM_DATE_004'
        ,'Dimension Lookup'
        ,'Error'
        ,'record_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimDate dd
        on dd.FullDate = mc.record_date

    where dd.DateKey is null;


    -- Validate SourceDate lookup
	-------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'source_date'
        ,convert(varchar(10), mc.source_date, 23)
        ,'FCM_DATE_005'
        ,'Dimension Lookup'
        ,'Error'
        ,'source_date could not be resolved to Curated.DimDate.'
        ,@validation_datetime
    from #MonthlyClaims mc

    left join Curated.DimDate dd
        on dd.FullDate = mc.source_date

    where dd.DateKey is null;


    /*
    -- Validate snapshot does not already exist
        As-reported design:
        Existing ClaimID + SnapshotDate must never be overwritten.
    -------------------------------------------------------------------------------------------
    */

    insert into Ctl.LoadValidationError
    (
		BatchID, ValidationStage, EntityName, RawRowID, SourceFileName
		,RecordIdentifier, ColumnName, InvalidValue, ValidationCode
		,ValidationType, Severity, ErrorMessage, ValidationDatetime
    )
    select
         mc.batch_id
        ,'CleanedToCurated'
        ,'ClaimMonthlySnapshot'
        ,null
        ,mc.source_file_name
        ,mc.claim_id
        ,'SnapshotDate'
        ,convert(varchar(10), mc.SnapshotDate, 23)
        ,'FCM_DUP_001'
        ,'Duplicate Validation'
        ,'Error'
        ,'ClaimID and SnapshotDate already exist in Curated.FactClaimMonthlySnapshot.'
        ,@validation_datetime
    from #MonthlyClaims mc

    inner join Curated.DimDate dd
        on dd.FullDate = mc.SnapshotDate

    where exists
    (
        select 1
        from Curated.FactClaimMonthlySnapshot fcm
        where fcm.ClaimID = mc.claim_id
          and fcm.SnapshotDateKey = dd.DateKey
    );


    -- Stops execution of script if validation errors exist; will return rather than throw
	-------------------------------------------------------------------------------------------
    if exists
    (
        select 1
        from Ctl.LoadValidationError
        where BatchID = @batch_id
          and ValidationStage = 'CleanedToCurated'
          and EntityName = 'ClaimMonthlySnapshot'
          and Severity = 'Error'
    )
    begin
        select
             Severity
            ,ValidationCode
            ,ValidationType
            ,count(*) as ValidationCount
        from Ctl.LoadValidationError

        where BatchID = @batch_id
          and ValidationStage = 'CleanedToCurated'
          and EntityName = 'ClaimMonthlySnapshot'

        group by
             Severity
            ,ValidationCode
            ,ValidationType

        order by
             ValidationCode;


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
          and EntityName = 'ClaimMonthlySnapshot'

        order by
             RecordIdentifier
            ,ValidationCode;

        return;
    end;


    -- Load FactClaimMonthlySnapshot
    -------------------------------------------------------------------------------------------
    begin try
        begin transaction;

        insert into Curated.FactClaimMonthlySnapshot
        (
             ClaimID

            ,PolicyKey
            ,ProgramKey
            ,PolicyholderKey
            ,CarrierKey
            ,GeographyKey

            ,SnapshotDateKey
            ,LossDateKey
            ,ReportedDateKey
            ,RecordDateKey
            ,SourceDateKey

            ,ClaimStatus
            ,DenialReason

            ,IndemnityReserve
            ,IndemnityPaid

            ,ALAEReserve
            ,ALAEPaid

            ,SalvageRecovery
            ,SubrogationRecovery
            ,DeductibleRecovery

            ,IndemnityReserveMovement
            ,IndemnityPaidMovement

            ,ALAEReserveMovement
            ,ALAEPaidMovement

            ,SalvageRecoveryMovement
            ,SubrogationRecoveryMovement
            ,DeductibleRecoveryMovement

            ,BatchID
        )
        select
             mc.claim_id

            ,dp.PolicyKey
            ,dpr.ProgramKey
            ,dph.PolicyholderKey
            ,dc.CarrierKey
            ,dg.GeographyKey

            ,dsnapshot.DateKey
            ,dloss.DateKey
            ,dreported.DateKey
            ,drecord.DateKey
            ,dsource.DateKey

            ,mc.claim_status
            ,mc.denial_reason

            ,mc.indemnity_reserve
            ,mc.indemnity_paid

            ,mc.alae_reserve
            ,mc.alae_paid

            ,mc.salvage_recovery
            ,mc.subrogation_recovery
            ,mc.deductible_recovery

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.indemnity_reserve
                     - [prior].IndemnityReserve
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.indemnity_paid
                     - [prior].IndemnityPaid
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.alae_reserve
                     - [prior].ALAEReserve
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.alae_paid
                     - [prior].ALAEPaid
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.salvage_recovery
                     - [prior].SalvageRecovery
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.subrogation_recovery
                     - [prior].SubrogationRecovery
             end

            ,case
                when [prior].SnapshotDate is null
                    then null
                else mc.deductible_recovery
                     - [prior].DeductibleRecovery
             end

            ,mc.batch_id
        from #MonthlyClaims mc

        inner join Curated.DimPolicy dp
            on dp.PolicyID = mc.policy_id

        inner join Curated.DimProgram dpr
            on dpr.ProgramName = mc.[program_name]

        inner join Curated.DimPolicyholder dph
            on dph.PolicyholderID = mc.policyholder_id

        inner join Curated.DimCarrier dc
            on dc.CarrierName = mc.carrier_company_name

        inner join Curated.DimGeography dg
            on dg.StateCode = mc.[state]

        inner join Curated.DimDate dsnapshot
            on dsnapshot.FullDate = mc.SnapshotDate

        inner join Curated.DimDate dloss
            on dloss.FullDate = mc.loss_date

        inner join Curated.DimDate dreported
            on dreported.FullDate = mc.reported_date

        inner join Curated.DimDate drecord
            on drecord.FullDate = mc.record_date

        inner join Curated.DimDate dsource
            on dsource.FullDate = mc.source_date


        outer apply
        (
            select top 1
                 p.SnapshotDate

                ,p.IndemnityReserve
                ,p.IndemnityPaid

                ,p.ALAEReserve
                ,p.ALAEPaid

                ,p.SalvageRecovery
                ,p.SubrogationRecovery
                ,p.DeductibleRecovery

            from
            (
                
                --Previously loaded as-reported snapshots
                select
                     prior_date.FullDate as SnapshotDate

                    ,fcm.IndemnityReserve
                    ,fcm.IndemnityPaid

                    ,fcm.ALAEReserve
                    ,fcm.ALAEPaid

                    ,fcm.SalvageRecovery
                    ,fcm.SubrogationRecovery
                    ,fcm.DeductibleRecovery

                from Curated.FactClaimMonthlySnapshot fcm

                inner join Curated.DimDate prior_date
                    on prior_date.DateKey = fcm.SnapshotDateKey

                where fcm.ClaimID = mc.claim_id
                  and prior_date.FullDate < mc.SnapshotDate


                union all


               -- Earlier snapshots within the current batch
                select
                     prior_mc.SnapshotDate

                    ,prior_mc.indemnity_reserve
                    ,prior_mc.indemnity_paid

                    ,prior_mc.alae_reserve
                    ,prior_mc.alae_paid

                    ,prior_mc.salvage_recovery
                    ,prior_mc.subrogation_recovery
                    ,prior_mc.deductible_recovery

                from #MonthlyClaims prior_mc

                where prior_mc.claim_id = mc.claim_id
                  and prior_mc.SnapshotDate < mc.SnapshotDate

            ) p

            order by
                 p.SnapshotDate desc

        ) as [prior]


        set @rows_inserted = @@rowcount;

        commit transaction;
    end try

    begin catch
        if @@trancount > 0
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