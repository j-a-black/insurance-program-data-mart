USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0020_usp_Load_ClaimsBatch.sql

Purpose:
	Validates then loads data from the 'Raw' schema to the 'Clean' schema.
----------------------------------------------------------------------------------------------------------------------------------------------
*/


create or alter procedure Cleaned.usp_LoadClaimsBatch
	@batch_id int
as
begin
	set nocount ON;
	set xact_abort ON;

	--declare @batch_id int = 9;
	
	declare @validation_datetime datetime2(3) = getdate();
	declare @clean_load_datetime datetime2(3) = getdate();

	-- Clear previous validation results for this batch.
	delete from Ctl.LoadValidationError
	where BatchID = @batch_id
		and ValidationStage = 'RawToCleaned'
		and EntityName = 'Claims'


	-- Validate raw batch exists
    -------------------------------------------------------------------------------------------------------------------------
	if not exists
	(
		select 1
		from [Raw].ClaimsData
		where batch_id = batch_id
	)
	begin
		insert into Ctl.LoadValidationError
        (
             BatchID
            ,ValidationStage
            ,EntityName
            ,RawRowID
            ,SourceFileName
            ,RecordIdentifier
            ,ColumnName
            ,InvalidValue
            ,ValidationCode
            ,ValidationType
            ,Severity
            ,ErrorMessage
            ,ValidationDatetime
        )
        values
        (
             @batch_id
            ,'RawToCleaned'
            ,'Claims'
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,'CLM_BATCH_001'
            ,'Batch Validation'
            ,'Error'
            ,'No Raw Claims rows were found for the supplied batch_id.'
            ,@validation_datetime
        );
	end


    -- Validate required values
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,v.column_name
        ,v.column_value
        ,'CLM_REQ_001'
        ,'Required Value'
        ,'Error'
        ,concat(v.column_name, ' is required.')
        ,@validation_datetime
    from [Raw].ClaimsData c

    cross apply
    (
        values
             ('claim_id',             c.claim_id)
            ,('policy_id',            c.policy_id)
            ,('policyholder_id',      c.policyholder_id)
            ,('program_name',         c.[program_name])
            ,('carrier_company_name', c.carrier_company_name)
            ,('reporting_month',      c.reporting_month)
            ,('claim_status',         c.claim_status)
            ,('state',                c.[state])
            ,('loss_date',            c.loss_date)
            ,('reported_date',        c.reported_date)
            ,('record_date',          c.record_date)
            ,('source_date',          c.source_date)
    ) v(column_name, column_value)

    where c.batch_id = @batch_id
      and nullif(trim(v.column_value), '') is null;


    -- Validate date conversions: expected format should be yyyy-mm-dd
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
        BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,v.column_name
        ,v.column_value
        ,'CLM_DATE_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name,' could not be converted to DATE using yyyy-mm-dd.')
        ,@validation_datetime
    from [Raw].ClaimsData c 

    cross apply
    (
        values
            ('loss_date',     c.loss_date)
            ,('reported_date', c.reported_date)
            ,('record_date',   c.record_date)
            ,('source_date',   c.source_date)
    ) v(column_name,column_value)

    where c.batch_id = @batch_id
        and nullif(trim(v.column_value),'') is not null
        and try_convert(date,v.column_value,23) is null;


    -- Validate reporting_month: expected format should be yyyy-mm
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'reporting_month'
        ,c.reporting_month
        ,'CLM_MONTH_001'
        ,'Data Type Conversion'
        ,'Error'
        ,'reporting_month must contain a valid yyyy-mm value.'
        ,@validation_datetime

    from [Raw].ClaimsData c
    where c.batch_id = @batch_id
        and nullif(trim(c.reporting_month),'') is not null
        and 
        (
            len(trim(c.reporting_month)) <> 7
            or substring(trim(c.reporting_month),5,1) <> '-'
            or try_convert(date,trim(c.reporting_month)+'-01',23) is null
        );


    -- Validate monetary conversions: expected format should be decimal(19,6)
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,v.column_name
        ,v.column_value
        ,'CLM_AMT_001'
        ,'Data Type Conversion'
        ,'Error'
        ,concat(v.column_name,' could not be converted to decimal(19,6).')
        ,@validation_datetime
    from [Raw].ClaimsData c

    cross apply
    (
        values
             ('indemnity_reserve',     c.indemnity_reserve)
            ,('indemnity_paid',        c.indemnity_paid)
            ,('alae_reserve',          c.alae_reserve)
            ,('alae_paid',             c.alae_paid)
            ,('salvage_recovery',      c.salvage_recovery)
            ,('subrogation_recovery',  c.subrogation_recovery)
            ,('deductible_recovery',   c.deductible_recovery)
    ) v(column_name, column_value)

    where c.batch_id = @batch_id
        and nullif(trim(v.column_value),'') is not null
        and try_convert(decimal(19,6),nullif(trim(v.column_value),'')) is null


    -- Validate non-negative financial balances
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,v.column_name
        ,v.column_value
        ,'CLM_AMT_002'
        ,'Business Rule'
        ,'Error'
        ,concat(v.column_name,' cannot contain a negative balance.')
        ,@validation_datetime
    from [Raw].ClaimsData c

    cross apply
    (
        values
             ('indemnity_reserve',     c.indemnity_reserve)
            ,('indemnity_paid',        c.indemnity_paid)
            ,('alae_reserve',          c.alae_reserve)
            ,('alae_paid',             c.alae_paid)
            ,('salvage_recovery',      c.salvage_recovery)
            ,('subrogation_recovery',  c.subrogation_recovery)
            ,('deductible_recovery',   c.deductible_recovery)
    ) v(column_name, column_value)

    where c.batch_id = @batch_id
        and try_convert(decimal(19,6),nullif(trim(v.column_value),'')) < 0;


    -- Validate loss_date <= reported_date
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'loss_date'
        ,c.loss_date
        ,'CLM_DATE_002'
        ,'Business Rule'
        ,'Error'
        ,'loss_date cannot occur after reported_date.'
        ,@validation_datetime
    from [Raw].ClaimsData c
    where c.batch_id = @batch_id
        AND try_convert(date,c.loss_date,23) > try_convert(date,c.reported_date, 23);


    -- Validate reported_date <= record_date
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'reported_date'
        ,c.reported_date
        ,'CLM_DATE_003'
        ,'Business Rule'
        ,'Error'
        ,'reported_date cannot occur after record_date.'
        ,@validation_datetime

    from [Raw].ClaimsData c
    where c.batch_id = @batch_id
        and try_convert(date,c.reported_date,23) > try_convert(date,c.record_date,23)


    -- Validate record_date belongs to reporting_month
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'record_date'
        ,c.record_date
        ,'CLM_MONTH_002'
        ,'Business Rule'
        ,'Error'
        ,'record_date does not fall within reporting_month.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    cross apply
    (
        values
        (try_convert(date,c.record_date,23),try_convert(date,trim(c.reporting_month)+'-01',23))
    ) v(record_date_value,reporting_month_start)

    where c.batch_id = @batch_id
        and v.record_date_value is not null
        and v.reporting_month_start is not null
        and
        (
            v.record_date_value < v.reporting_month_start
            OR v.record_date_value > eomonth(v.reporting_month_start)
        );


    -- Validate state code length
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'state'
        ,c.[state]
        ,'CLM_STATE_001'
        ,'Business Rule'
        ,'Error'
        ,'state must contain a two-character state code.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    where c.batch_id = @batch_id
      and nullif(trim(c.[state]), '') is not null
      and len(trim(c.[state])) <> 2;


    /*
    -- Validate claim_id is assigned to one policy_id

    A claim_id should not point to more that one policy_id
    This checks:
        - rows already in Cleaned table
        - other rows in current Raw batch
    -------------------------------------------------------------------------------------------------------------------------
    */
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'policy_id'
        ,c.policy_id
        ,'CLM_REL_001'
        ,'Relationship Validation'
        ,'Error'
        ,'claim_id is associated with more than one policy_id.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    where c.batch_id = @batch_id
        and nullif(trim(c.claim_id),'') is not null
        and nullif(trim(c.policy_id),'') is not null
        and
        (
            exists
            (
                select 1
                from [Raw].ClaimsData c2
                where c2.batch_id = @batch_id
                    and trim(c2.claim_id) = trim(c.claim_id)
                    and nullif(trim(c2.policy_id),'') is not null
                    and trim(c2.policy_id) <> trim(c.policy_id)
            )
            or exists
            (
                select 1
                from Cleaned.ClaimsData cc
                where cc.claim_id = trim(c.claim_id)
                    and cc.policy_id <> c.policy_id
            )
        );


    /*
    -- Validate claim_id is assigned to one policyholder_id

    A claim_id should not point to more that one policyholder_id
    This checks:
        - rows already in Cleaned table
        - other rows in current Raw batch
    -------------------------------------------------------------------------------------------------------------------------
    */
    insert Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'policyholder_id'
        ,c.policyholder_id
        ,'CLM_REL_002'
        ,'Relationship Validation'
        ,'Error'
        ,'claim_id is associated with more than one policyholder_id.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    where c.batch_id = @batch_id
        and nullif(trim(c.claim_id),'') is not null
        and nullif(trim(c.policyholder_id),'') is not null

        and
        (
            exists
            (
                select 1
                from [Raw].ClaimsData c2
                where c2.batch_id = @batch_id
                    and trim(c2.claim_id) = trim(c.claim_id)
                    and nullif(trim(c2.policyholder_id),'') is not null 
                    and trim(c2.policyholder_id) <> trim(c.policyholder_id)
            )
          
            or exists
            (
                select 1
                from Cleaned.ClaimsData cc
                where cc.claim_id = trim(c.claim_id)
                    and cc.policyholder_id <> trim(c.policyholder_id)
            )
        )


    /*
    -- Validate claim_id is assigned to one program_name

    A claim_id should not point to more that one program_name
    This checks:
        - rows already in Cleaned table
        - other rows in current Raw batch
    -------------------------------------------------------------------------------------------------------------------------
    */
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'program_name'
        ,c.[program_name]
        ,'CLM_REL_003'
        ,'Relationship Validation'
        ,'Error'
        ,'claim_id is associated with more than one program_name.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    where c.batch_id = @batch_id
        and nullif(trim(c.claim_id),'') is not null
        and nullif(trim(c.[program_name]),'') is not null

        and
        (
            exists
            (
                select 1
                from [Raw].ClaimsData c2
                where c2.batch_id = @batch_id
                    and trim(c2.claim_id) = trim(c.claim_id)
                    and nullif(trim(c2.[program_name]),'') is not null
                    and trim(c2.[program_name]) <> trim(c.[program_name])
            )
            or exists
            (
                select 1
                from Cleaned.ClaimsData cc
                where cc.claim_id = c.claim_id
                    and cc.[program_name] <> c.[program_name]
            )
        )


    -- Warning: denial reason populated when status is not denied
    -------------------------------------------------------------------------------------------------------------------------
    insert into Ctl.LoadValidationError
    (
         BatchID
        ,ValidationStage
        ,EntityName
        ,RawRowID
        ,SourceFileName
        ,RecordIdentifier
        ,ColumnName
        ,InvalidValue
        ,ValidationCode
        ,ValidationType
        ,Severity
        ,ErrorMessage
        ,ValidationDatetime
    )
    select
         c.batch_id
        ,'RawToCleaned'
        ,'Claims'
        ,c.RawRowID
        ,c.source_file_name
        ,nullif(trim(c.claim_id), '')
        ,'denial_reason'
        ,c.denial_reason
        ,'CLM_WARN_001'
        ,'Business Rule'
        ,'Warning'
        ,'denial_reason is populated while claim_status is not Denied.'
        ,@validation_datetime
    from [Raw].ClaimsData c

    where c.batch_id = @batch_id
        and nullif(trim(c.denial_reason),'') is not null
        and upper(trim(c.claim_status)) <> 'DENIED'


    -- Prevent same Raw batch from loading to Cleaned twice
    -------------------------------------------------------------------------------------------------------------------------
    if exists
    (
        select 1
        from Cleaned.ClaimsData c
        where c.batch_id = @batch_id
    )
    begin
        insert into Ctl.LoadValidationError
        (
             BatchID
            ,ValidationStage
            ,EntityName
            ,RawRowID
            ,SourceFileName
            ,RecordIdentifier
            ,ColumnName
            ,InvalidValue
            ,ValidationCode
            ,ValidationType
            ,Severity
            ,ErrorMessage
            ,ValidationDatetime
        )
        values
        (
             @batch_id
            ,'RawToCleaned'
            ,'Claims'
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,'CLM_BATCH_002'
            ,'Duplicate Batch'
            ,'Error'
            ,'This Claims batch has already been loaded to Cleaned.'
            ,@validation_datetime
        );
    end;



    -- Stops execution of script if validation errors exist; will return rather than throw
    -------------------------------------------------------------------------------------------------------------------------
    if exists
    (
        select 1
        from Ctl.LoadValidationError
        where BatchID = @batch_id
            and ValidationStage = 'RawToCleaned'
            and EntityName = 'Claims'
            and Severity = 'Error'
    )
    begin
        -- Validation summary
        select
            Severity
            ,COUNT(*) as ValidationCount
        from Ctl.LoadValidationError
        where BatchID = @batch_id
            and ValidationStage = 'RawToCleaned'
            and EntityName = 'Claims'
        group by Severity

        order by
            case Severity
                when 'Error' then 1
                when 'Warning' then 2
            else 3
            end;


        -- Detailed validation results
        select
            ValidationErrorID
            ,BatchID
            ,ValidationStage
            ,EntityName
            ,RawRowID
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
            and ValidationStage = 'RawToCleaned'
            and EntityName = 'Claims'

        order by
            case Severity
                when 'Error' then 1
                when 'Warning' then 2
            else 3
            end
            ,SourceFileName
            ,RawRowID
            ,ValidationErrorID;


        return;
    end


    -- Validation passed; technical/system issues will rollback and throw.
    -------------------------------------------------------------------------------------------------------------------------
    BEGIN TRY
        begin transaction;


        insert into Cleaned.ClaimsData
        (
             claim_id
            ,policy_id
            ,policyholder_id
            ,[program_name]
            ,carrier_company_name

            ,loss_date
            ,reported_date
            ,record_date
            ,reporting_month

            ,claim_status
            ,[state]

            ,indemnity_reserve
            ,indemnity_paid
            ,alae_reserve
            ,alae_paid
            ,salvage_recovery
            ,subrogation_recovery
            ,deductible_recovery

            ,denial_reason
            ,source_date

            ,tpa_name
            ,source_file_name
            ,raw_load_datetime
            ,clean_load_datetime
            ,batch_id
        )
        select
             trim(c.claim_id)
            ,trim(c.policy_id)
            ,trim(c.policyholder_id)
            ,trim(c.[program_name])
            ,trim(c.carrier_company_name)

            ,convert(date, trim(c.loss_date), 23)
            ,convert(date, trim(c.reported_date), 23)
            ,convert(date, trim(c.record_date), 23)
            ,trim(c.reporting_month)

            ,trim(c.claim_status)
            ,upper(trim(c.[state]))

            ,try_convert(decimal(19,2),nullif(trim(c.indemnity_reserve), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.indemnity_paid), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.alae_reserve), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.alae_paid), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.salvage_recovery), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.subrogation_recovery), ''))
            ,try_convert(decimal(19,2),nullif(trim(c.deductible_recovery), ''))

            ,nullif(trim(c.denial_reason), '')

            ,convert(date, trim(c.source_date), 23)

            ,c.tpa_name
            ,c.source_file_name
            ,c.raw_load_datetime
            ,@clean_load_datetime
            ,c.batch_id

        from [Raw].ClaimsData c
        where c.batch_id = @batch_id;

        commit transaction;
    end try

    begin catch
        if @@TRANCOUNT > 0
            rollback transaction;

        throw;
    end catch;


    -- Successful load results; warning returned even though they do not block load.
    -------------------------------------------------------------------------------------------------------------------------
    select
        @batch_id   as BatchID
        ,count(*)   as RowsLoaded
        ,@clean_load_datetime   as CleanLoadDatetime
    from Cleaned.ClaimsData
    where batch_id = @batch_id

    select
         ValidationErrorID
        ,BatchID
        ,RawRowID
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
      and ValidationStage = 'RawToCleaned'
      and EntityName = 'Claims'
      and Severity = 'Warning'

    order by
         SourceFileName
        ,RawRowID
        ,ValidationErrorID;
end;
go