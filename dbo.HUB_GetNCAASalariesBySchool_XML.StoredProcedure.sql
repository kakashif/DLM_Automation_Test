USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAASalariesBySchool_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetNCAASalariesBySchool_XML]
    @schoolId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/13/2013
-- Description:	Get list years profile for school
-- Update: 03/19/2013 - John Lin - break up staff into its own XML
--         04/22/2014 - John Lin - add note for private school
--         11/06/2014 - John Lin - add rgb
--         11/10/2014 - John Lin - abbr from SMG_Teams
--         03/30/2015 - John Lin - adjust for season year differences
--         10/01/2015 - John Lin - add last year bonus
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;      

    DECLARE @note VARCHAR(MAX) = 'Compensation for private-school coaches is based on the most recent, publicly-available documents, which include pay figures from a prior calendar year.'
    
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)    
    SELECT
	(
	    SELECT
	    (
	        SELECT
	        (
	            SELECT 'true' AS 'json:Array',
	                   fncs.year, fnc.first_name + ' ' + fnc.last_name AS coach_name,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.school_pay), 1), 2) AS school_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.other_pay), 1), 2) AS other_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.total_pay), 1), 2) AS total_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.max_bonus), 1), 2) AS max_bonus,
                       CASE
                           WHEN fncs.last_year_bonus IS NULL THEN '--'
                           ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.last_year_bonus), 1), 2)
                       END AS last_year_bonus
                  FROM SportsEditDB.dbo.Feeds_NCAA_Schools fns
                 INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
                    ON fncs.school_id = fns.id AND fncs.position = 'coach'
                 INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
                    ON fnc.id = fncs.coach_id AND fnc.sport = 'ncaab'
                 WHERE fns.id = @schoolId
                 ORDER BY fncs.year DESC
                   FOR XML RAW('ncaab'), TYPE
            ),
            (
                SELECT 'true' AS 'json:Array',
                       fncs.year, fnc.first_name + ' ' + fnc.last_name AS coach_name,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.school_pay), 1), 2) AS school_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.other_pay), 1), 2) AS other_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.total_pay), 1), 2) AS total_pay,
                       '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.max_bonus), 1), 2) AS max_bonus,
                       CASE
                           WHEN fncs.last_year_bonus IS NULL THEN '--'
                           ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.last_year_bonus), 1), 2)
                       END AS last_year_bonus
                  FROM SportsEditDB.dbo.Feeds_NCAA_Schools fns
                 INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
                    ON fncs.school_id = fns.id AND fncs.position = 'coach'
                 INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
                    ON fnc.id = fncs.coach_id AND fnc.sport = 'ncaaf'
                 WHERE fns.id = @schoolId
                 ORDER BY fncs.year DESC
                   FOR XML RAW('ncaaf'), TYPE
            )
            FOR XML RAW('coach'), TYPE
        ),
        (    
            SELECT 'true' AS 'json:Array',
                   fncs.year, fnc.first_name + ' ' + fnc.last_name AS coach_name,
                   '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.school_pay), 1), 2) AS school_pay,
                   '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.other_pay), 1), 2) AS other_pay,
                   '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.total_pay), 1), 2) AS total_pay,
                   '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.max_bonus), 1), 2) AS max_bonus,
                   CASE
                       WHEN fncs.last_year_bonus IS NULL THEN '--'
                       ELSE '$' + PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, fncs.last_year_bonus), 1), 2)
                   END AS last_year_bonus
              FROM SportsEditDB.dbo.Feeds_NCAA_Schools fns
             INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
                ON fncs.school_id = fns.id AND fncs.position = 'director'
             INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches fnc
                ON fnc.id = fncs.coach_id
             WHERE fns.id = @schoolId
             ORDER BY fncs.year DESC
               FOR XML RAW('director'), TYPE
         )         
         FOR XML RAW('staffs'), TYPE
    ),
    (
       SELECT TOP 1
              fns.name AS school_name,
              fncs.conference,
              st.team_abbreviation AS team_abbr,
              st.rgb AS team_rgb,
              (CASE
                  WHEN fns.is_private IS NOT NULL AND fns.is_private = 1 THEN @note
                  ELSE ''
              END) AS note
         FROM SportsEditDB.dbo.Feeds_NCAA_Schools fns
        INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Coaches_Salaries fncs
           ON fncs.school_id = fns.id           
        INNER JOIN SportsEditDB.dbo.Feeds_NCAA_Schools_Mappings fnsm
           ON fnsm.id = fncs.school_id
         LEFT JOIN SportsDB.dbo.SMG_Teams st
           ON st.season_key <= fncs.year AND st.team_key = fnsm.team_key AND st.team_abbreviation IS NOT NULL
        WHERE fns.id = @schoolId
        ORDER BY fncs.year DESC
          FOR XML RAW('profile'), TYPE
    )
    FOR XML PATH(''), ROOT('edits')
    
    SET NOCOUNT OFF;
END

GO
