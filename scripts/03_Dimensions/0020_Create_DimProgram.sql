use InsurancePrograms;
GO

/*
----------------------------------------------------------------------------------------------------------------------------------------------
Script Name:
	02_Create_DimProgram.sql

Purpose:
	Creates Policy dimension.

----------------------------------------------------------------------------------------------------------------------------------------------
*/


-- Create new table if one does not exist.
IF OBJECT_ID('Curated.DimProgram','U') IS NULL
BEGIN
	CREATE TABLE Curated.DimProgram
	(
		ProgramKey		int				identity(1,1) not null
		,ProgramCode	varchar(10)		not null
		,ProgramName	varchar(100)	not null
		,PrimaryLineOfBusiness	varchar(100)	not null
		,IsActive		int				not null

		constraint PK_DimProgram
			primary key (ProgramKey),

		constraint UQ_DimProgram_ProgramCode
			unique (ProgramCode),

		constraint UQ_DimProgram_ProgramName
			unique (ProgramName)
	);
END


-- Insert unknown program value with 0 key
if not exists
(
	select 1
	from Curated.DimProgram
	where ProgramKey = 0
)
begin
	set identity_insert Curated.DimProgram ON;

	insert into Curated.DimProgram 
	(ProgramKey,ProgramCode,ProgramName,PrimaryLineOfBusiness,IsActive)
	values 
	(0,'99','Unknown','Unknown',1)

	set identity_insert Curated.DimProgram OFF;
end