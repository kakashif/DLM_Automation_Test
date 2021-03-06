USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAASalariesContract_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAASalariesContract_XML]
    @coachId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 10/28/2014
-- Description:	Get list contract
-- Update: 11/10/2014 - John Lin - abbr from SMG_Teams
--         10/07/2015 - John Lin - return only current year
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @media_root VARCHAR(100) = 'SMG/'
    DECLARE @coach_name VARCHAR(100)
	DECLARE @head_shot VARCHAR(100)
    DECLARE @year INT
    DECLARE @total_pay VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @team_rgb VARCHAR(100)
    -- extra
    DECLARE @sport VARCHAR(100)
    DECLARE @school_id INT
    DECLARE @team_key VARCHAR(100)

    
    SELECT @coach_name = first_name + ' ' + last_name, @head_shot = head_shot, @sport = sport
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches
     WHERE id = @coachId

    IF (@head_shot <> '')
    BEGIN
        SET @head_shot = @media_root + @head_shot + '_s.jpg'
    END

    SELECT TOP 1 @year = [year], @total_pay = total_pay, @school_id = school_id
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries
     WHERE coach_id = @coachId
     ORDER BY [year] DESC

    IF (@total_pay <> '')
    BEGIN
        SET @total_pay = '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, @total_pay), 1), 2)
    END

    SELECT @team_key = team_key
      FROM SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings
     WHERE id = @school_id AND sport = @sport

    SELECT @team_abbr = team_abbreviation, @team_rgb = rgb
      FROM SportsDB.dbo.SMG_Teams
     WHERE season_key = @year AND team_key = @team_key


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)    
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               fncs.[year], fncn.note        
          FROM SportsEditDB.dbo.Feeds_NCAA_Contract_Notes fncn
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
            ON fncs.contract_id = fncn.contract_id AND fncs.coach_id = @coachId AND fncs.[year] = @year
         ORDER BY fncs.[year] DESC
           FOR XML RAW('years'), TYPE
    ),
    (
       SELECT @coach_name AS coach_name, @head_shot AS head_shot, @year AS 'year', @total_pay AS total_pay,
              @team_abbr AS team_abbr, @team_rgb AS team_rgb
          FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')
    
    
    SET NOCOUNT OFF;
END

GO
