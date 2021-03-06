USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventLeaders_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventLeaders_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	06/27/2014
-- Description:	get event leaders
-- Update:		09/09/2014 - John Lin - flip team name
--				10/08/2014 - ikenticus - suppress node when no leaders
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--              06/23/2015 - John Lin - STATS migration
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_name VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_name VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS leaders
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

	-- No leaders displayed in PRD
    IF (@leagueName = 'mls')
    BEGIN
        SELECT '' AS leaders
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END

    DECLARE @leaders TABLE
    (
        team_key       VARCHAR(100),
        category       VARCHAR(100),
        category_order INT,
        player_value   VARCHAR(100),
        stat_value     VARCHAR(100),
        stat_order     INT
    )

    INSERT INTO @leaders (team_key, category, category_order, player_value, stat_order)
    VALUES (@away_key, 'LEADERS', 0, @away_name, 0),
           (@home_key, 'LEADERS', 0, @home_name, 0)
           
    INSERT INTO @leaders (team_key, category, category_order, player_value, stat_value, stat_order)
    SELECT team_key, category, category_order, player_value, stat_value, stat_order
      FROM dbo.SMG_Events_Leaders
     WHERE event_key = @event_key AND team_key IN (@away_key, @home_key)

	-- Suppress leaders node if no data
	IF ((SELECT COUNT(*) FROM @leaders) = 2)
	BEGIN
        SELECT '' AS leaders
        FOR XML PATH(''), ROOT('root')
        
        RETURN
	END


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
        SELECT 'true' AS 'json:Array',
               l.category, 
               (
                   SELECT 'true' AS 'json:Array',
                          l_a.player_value, l_a.stat_value
                     FROM @leaders l_a
                    WHERE l_a.category_order = l.category_order AND l_a.team_key = @away_key
                    ORDER BY l_a.stat_order ASC
	                  FOR XML RAW('away'), TYPE
	           ),
	           (
	               SELECT 'true' AS 'json:Array',
	                      l_h.player_value, l_h.stat_value
	                 FROM @leaders l_h
                    WHERE l_h.category_order = l.category_order AND l_h.team_key = @home_key
                    ORDER BY l_h.stat_order ASC
	                  FOR XML RAW('home'), TYPE
               )
          FROM @leaders l
         GROUP BY l.category_order, l.category
         ORDER BY l.category_order ASC
           FOR XML RAW('leaders'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END


GO
