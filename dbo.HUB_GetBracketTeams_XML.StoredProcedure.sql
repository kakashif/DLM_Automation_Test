USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetBracketTeams_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetBracketTeams_XML]
    @sport VARCHAR(100),
    @year INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/26/2015
-- Description:	get bracket teams
-- Update: 07/10/2015 - John Lin - STATS team records
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = 'l.ncaa.org.mbasket'
    DECLARE @league_name VARCHAR(100) = 'ncaab'
    DECLARE @season_key INT = (@year - 1)

    IF (@sport = 'womens-basketball')
    BEGIN
        SET @league_key = 'l.ncaa.org.wbasket'
        SET @league_name = 'ncaaw'
    END


    DECLARE @teams TABLE 
	(
        [key] VARCHAR(100),
        seed INT,
        display VARCHAR(100),
        abbr VARCHAR(100),
        logo VARCHAR(100),
        record VARCHAR(100)
	)
    INSERT INTO @teams ([key], seed, display)
    SELECT team_key, seed, team_display
      FROM dbo.Edit_Bracket_Teams
     WHERE league_key = @league_key AND season_key = @season_key

	UPDATE t
	   SET t.abbr = st.team_abbreviation,
	       t.logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/60/' + st.team_abbreviation + '.png'
	  FROM @teams t
	 INNER JOIN dbo.SMG_Teams st
	    ON st.season_key = @season_key AND st.team_key = t.[key]

    UPDATE @teams
       SET record = dbo.SMG_fn_Team_Records(@league_name, @season_key, [key], GETDATE())

    -- play-in
    UPDATE @teams
       SET display = abbr, record = '', logo = ''
     WHERE [key] IN ('l.ncaa.org.mbasket-t.PI64', 'l.ncaa.org.mbasket-t.PI65', 'l.ncaa.org.mbasket-t.PI66', 'l.ncaa.org.mbasket-t.PI67')
     


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
           SELECT 'true' AS 'json:Array',
                  [key], abbr, seed, display, record, logo
             FROM @teams
              FOR XML RAW('teams'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	    
    SET NOCOUNT OFF;
END




GO
