USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAATeams_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAATeams_XML]
   @conference VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/22/2014
-- Description: get NCAA teams
-- Update: 09/08/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    -- NEED TO PUT INTO A TABLE
    DECLARE @conference_key VARCHAR(100)
    
    IF (@conference = 'sec')
    BEGIN
        SET @conference_key = '/sport/football/conference:12'
    END

    DECLARE @mapping TABLE
    (
        league_key  VARCHAR(100),
        league_name VARCHAR(100)
    )
    INSERT INTO @mapping (league_key, league_name)
    VALUES (dbo.SMG_fnGetLeagueKey('ncaab'), 'ncaab'), (dbo.SMG_fnGetLeagueKey('ncaaf'), 'ncaaf'), (dbo.SMG_fnGetLeagueKey('ncaaw'), 'ncaaw')
    
    DECLARE @info TABLE
    (
        team_first VARCHAR(100),
        team_last  VARCHAR(100),
        team_logo  VARCHAR(100),
        team_link  VARCHAR(100)
    )
    
    INSERT INTO @info (team_first, team_last, team_logo, team_link)
    SELECT st.team_first, st.team_last,
          'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/220/' + st.team_abbreviation + '.png',
          'ncaa/' + @conference + '/' + st.team_slug + '/'
      FROM dbo.SMG_Teams st
     INNER JOIN @mapping m
        ON m.league_key = st.league_key
     INNER JOIN dbo.SMG_Default_Dates sdd
        ON sdd.league_key = m.league_name AND sdd.team_season_key = st.season_key AND sdd.page = 'schedules'
     WHERE st.conference_key = @conference_key


    SELECT
    (
        SELECT team_first, team_last, team_logo, team_link
          FROM @info
         GROUP BY team_first, team_last, team_logo, team_link
         ORDER BY team_first ASC
           FOR XML RAW('schools'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
            
    SET NOCOUNT OFF 
END


GO
