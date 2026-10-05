USE InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	0040_usp_Load_DimAgency.sql

Purpose:
	Populates the Agency dimension table using by sourcing Cleaned.PolicyData table. 
----------------------------------------------------------------------------------------------------------------------------------------------
*/

create or alter procedure Curated.usp_LoadDimAgency
as
begin
	insert into Curated.DimAgency
	(AgencyName)
	select distinct
		agency_name
	from Cleaned.PolicyData cp
	where nullif(trim(cp.agency_name),'') is not null
		and not exists
		(
			select 1
			from Curated.DimAgency da
			where da.AgencyName = trim(cp.agency_name)
		);
end;
go