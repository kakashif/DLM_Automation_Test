USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAASalariesByCoach_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAASalariesByCoach_XML]
    @coachId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/27/2013
-- Description:	Get list years profile for coach
-- Update: 04/01/2013 - add head shot
--                    - add comment for Mohit
--         08/07/2013 - John Lin - remove cdn host for head shot
--         10/22/2013 - John Lin - add school record
--         11/06/2014 - John Lin - add rgb
--         11/10/2014 - John Lin - abbr from SMG_Teams
--         10/01/2015 - John Lin - last year bonus
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @media_root VARCHAR(100) = 'SMG/'

    DECLARE @school_id INT
    DECLARE @career_record VARCHAR(100)
    DECLARE @school_record VARCHAR(100)
    DECLARE @at_school_since VARCHAR(100)
    DECLARE @year INT
    DECLARE @team_rgb VARCHAR(100)
    DECLARE @position VARCHAR(100)

	SELECT TOP 1 @school_id = fncs.school_id, @career_record = fncs.career_record, @school_record = fncs.school_record,
	             @at_school_since = fncs.at_school_since, @year = fncs.[year], @position = fncs.position
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
     INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
        ON fncs.coach_id = fnc.id
     WHERE fnc.id = @coachId
     ORDER BY fncs.year DESC
     
    DECLARE @coach_name VARCHAR(100)
    DECLARE @birthday VARCHAR(100)
    DECLARE @sport VARCHAR(100)
    DECLARE @school_name VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @head_shot VARCHAR(100)
     
    SELECT @coach_name = first_name + ' ' + last_name, @birthday = birthday, @sport = sport, @head_shot = ISNULL(head_shot, '')
      FROM SportsEditDB.dbo.Feeds_NCAA_Coaches
     WHERE id = @coachId

    SELECT @school_name = name
      FROM SportsEditDB.dbo.Feeds_NCAA_Schools
     WHERE id = @school_id

    IF (@sport = '')
    BEGIN
        SELECT TOP 1 @team_abbr = st.team_abbreviation, @team_rgb = st.rgb
          FROM SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings fnsm
          LEFT JOIN SportsDB.dbo.SMG_Teams st
            ON st.season_key = @year AND st.team_key = fnsm.team_key           
         WHERE fnsm.id = @school_id
    END
    ELSE
    BEGIN
        SELECT @team_abbr = st.team_abbreviation, @team_rgb = st.rgb
          FROM SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings fnsm
          LEFT JOIN SportsDB.dbo.SMG_Teams st
            ON st.season_key = @year AND st.team_key = fnsm.team_key           
         WHERE fnsm.id = @school_id AND fnsm.sport = @sport
    END

    IF (@head_shot <> '')
    BEGIN
       SELECT @head_shot = @media_root + @head_shot + '_s.jpg'
    END
    
    IF (@sport = 'ncaaf' AND @position = 'coach')
    BEGIN
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)    
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               fncs.year, fncs.position, fncs.conference, fns.name AS school_name,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.school_pay), 1), 2) AS school_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.other_pay), 1), 2) AS other_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.total_pay), 1), 2) AS total_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.max_bonus), 1), 2) AS max_bonus,
               CASE
                   WHEN fncs.last_year_bonus IS NULL THEN '--'
                   ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.last_year_bonus), 1), 2)
               END AS last_year_bonus
          FROM SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
            ON fncs.coach_id = fnc.id
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools fns
            ON fns.id = fncs.school_id
         WHERE fnc.id = @coachId
         ORDER BY fncs.year DESC
           FOR XML RAW('years'), TYPE
    ),
    (
       SELECT @coach_name AS coach_name,
              @school_name AS school_name,
              @birthday AS birthday,
              @career_record AS career_record,
              @school_record AS school_record,
              @at_school_since AS at_school_since,
              @team_abbr AS team_abbr,
              @team_rgb AS team_rgb,
              @head_shot AS head_shot
          FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')
    END
    ELSE
    BEGIN
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)    
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               fncs.year, fncs.position, fncs.conference, fns.name AS school_name,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.school_pay), 1), 2) AS school_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.other_pay), 1), 2) AS other_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.total_pay), 1), 2) AS total_pay,
               '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.max_bonus), 1), 2) AS max_bonus
          FROM SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
            ON fncs.coach_id = fnc.id
         INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools fns
            ON fns.id = fncs.school_id
         WHERE fnc.id = @coachId
         ORDER BY fncs.year DESC
           FOR XML RAW('years'), TYPE
    ),
    (
       SELECT @coach_name AS coach_name,
              @school_name AS school_name,
              @birthday AS birthday,
              @career_record AS career_record,
              @school_record AS school_record,
              @at_school_since AS at_school_since,
              @team_abbr AS team_abbr,
              @team_rgb AS team_rgb,
              @head_shot AS head_shot
          FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')
    END
    SET NOCOUNT OFF;
END

GO
