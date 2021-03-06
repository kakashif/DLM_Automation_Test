USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetTeamLeaders_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetTeamLeaders_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/28/2015
  -- Description: get team leaders for mobile
  -- Update: 04/07/2015 - John Lin - replace head shot logic
  --         04/08/2015 - John Lin - new head shot logic
  --         05/18/2015 - John Lin - return error
  --         06/23/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)    
    DECLARE @domain VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/'

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'
     
    SELECT @team_key = team_key, @team_abbr = team_abbreviation
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

    DECLARE @leaders TABLE
    (
        player_key     VARCHAR(100),
        category       VARCHAR(100),
        category_order INT,
        player_value   VARCHAR(100),
        stat_value     VARCHAR(100),
        stat_order     INT,
        head_shot      VARCHAR(200)
    )
    INSERT INTO @leaders (player_key, category, category_order, player_value, stat_value, stat_order)
    SELECT player_key, category, category_order, player_value, stat_value, stat_order
      FROM dbo.SMG_Teams_Leaders
     WHERE season_key = @season_key AND sub_season_type = 'season-regular' AND team_key = @team_key



    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'nhl'))
    BEGIN
        UPDATE l
           SET l.head_shot = @domain + sr.head_shot + '90x90/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.season_key = @season_key AND sr.team_key = @team_key AND sr.player_key = l.player_key AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL
    END
    ELSE
    BEGIN
        UPDATE @leaders
           SET head_shot = ''
    END
    

    SELECT
    (
        SELECT l.category AS category_name,
               (
                   SELECT c_l.player_value, c_l.stat_value, head_shot, c_l.stat_order
                     FROM @leaders c_l
                    WHERE c_l.category_order = l.category_order
                    ORDER BY c_l.stat_order ASC
                      FOR XML RAW('category'), TYPE
               )                
          FROM @leaders l
         GROUP BY l.category, l.category_order
         ORDER BY l.category_order ASC
           FOR XML RAW('leaders'), TYPE   
    )
    FOR XML PATH(''), ROOT('root')

     
         	
END

GO
