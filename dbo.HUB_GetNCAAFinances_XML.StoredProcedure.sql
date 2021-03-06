USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAFinances_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAAFinances_XML]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/27/2013
-- Description:	Get list of colleges' finance
-- Update: 03/22/2013 - John Lin - add credits
--         05/21/2015 - John Lin - add conference
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @year INT
    
    SELECT @year = MAX(fnse.year)
      FROM SportsEditDB.dbo.Feeds_NCAA_School_Expenses fnse
     INNER JOIN SportsEditDB.dbo.Feeds_NCAA_School_Revenues fnsr
        ON fnsr.school_id = fnse.school_id AND fnsr.year = fnse.year

    DECLARE @finances TABLE
    (
        school_id INT,
        school_name VARCHAR(100),
        conference VARCHAR(100),
        total_expenses INT,
        total_revenues INT,
        subsidy INT,
        percent_subsidy DECIMAL(12, 2)        
    );
    
    INSERT INTO @finances (school_id, school_name, conference, total_expenses, total_revenues, subsidy, percent_subsidy)
    SELECT fnse.school_id, fns.name, fnse.conference, fnse.total_expenses, fnsr.total_revenues, fnsr.subsidy, fnsr.percent_subsidy
          FROM SportsEditDB.dbo.Feeds_NCAA_School_Expenses fnse
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_School_Revenues fnsr
            ON fnsr.school_id = fnse.school_id AND fnsr.year = fnse.year AND fnsr.year = @year
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools fns
            ON fns.id = fnsr.school_id
            
    -- spotlight
    DECLARE @school_id INT       
    DECLARE @current_total INT
    DECLARE @previous_total INT
    DECLARE @delta VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
        
    SELECT TOP 1 @school_id = school_id, @current_total = total_revenues
      FROM @finances
     ORDER BY total_revenues DESC
     
    SELECT TOP 1 @previous_total = total_revenues
      FROM SportsEditDB.dbo.Feeds_NCAA_School_Revenues
     WHERE year = (@year - 1) AND school_id = @school_id
      
    IF (CONVERT(DECIMAL(18,2), @current_total) > CONVERT(DECIMAL(18,2), @previous_total))
    BEGIN
        SELECT @delta = '+' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, CONVERT(DECIMAL(18,2), @current_total) - CONVERT(DECIMAL(18,2), @previous_total)), 1), 2)
    END
    ELSE
    BEGIN
        SELECT @delta = '-' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, CONVERT(DECIMAL(18,2), @previous_total) - CONVERT(DECIMAL(18,2), @current_total)), 1), 2)
    END
        
    SELECT @team_abbr = team_abbr
      FROM SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings
     WHERE id = @school_id AND sport = 'ncaaf'

    SELECT
	(
        SELECT school_id, school_name, conference,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, total_revenues), 1), 2) AS total_revenues,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, total_expenses), 1), 2) AS total_expenses,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, subsidy), 1), 2) AS subsidy,
               percent_subsidy
          FROM @finances AS f
         ORDER BY f.total_revenues DESC
           FOR XML RAW('finances'), TYPE
    ),
    (
        SELECT 'NCAA Finances' AS ribbon
           FOR XML RAW('positions'), TYPE
    ),
    (
       SELECT @year AS current_year,
              '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @current_total), 1), 2) AS current_total,
              (@year - 1) AS previous_year,
              '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @previous_total), 1), 2) AS previous_total,
              @delta AS delta,
              @team_abbr AS team_abbr,
              'TOP SCHOOL REVENUE' AS tag,
              (SELECT credits
                 FROM SportsEditDB.dbo.Feeds_Credits
                WHERE [type] = 'finance') AS credits
          FOR XML RAW('spotlight'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')

    SET NOCOUNT OFF;
END

GO
