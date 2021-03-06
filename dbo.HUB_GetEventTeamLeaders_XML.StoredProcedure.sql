USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventTeamLeaders_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventTeamLeaders_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 06/27/2014
-- Description:	get event leaders
-- Update:		08/22/2014 - ikenticus - commenting out event_status <> pre-event, rearranged team_leaders nesting order
--				09/02/2014 - thlam - fixing the typo on away_key and forcing json:Array
--              11/17/2014 - John Lin - add ncaab
--              02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
--              07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

    IF (@event_status <> 'pre-event')
    BEGIN
        SELECT '' AS team_leaders
        FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @team_leaders TABLE
    (
        category_order INT,
        category       VARCHAR(100),
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        name           VARCHAR(100),
        value          VARCHAR(100)
    )

    IF (@leagueName = 'ncaab')
    BEGIN
        -- points
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 1, 'points', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'points-scored-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 1, 'points', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'points-scored-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        -- rebounds
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 2, 'rebounds', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'rebounds-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 2, 'rebounds', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'rebounds-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        -- assists
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 3, 'assists', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'assists-total-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 3, 'assists', team_key, player_key, CAST(value AS DECIMAL(4, 1))
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'assists-total-per-game' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        -- passing
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 1, 'passing', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'passes-yards-gross' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 1, 'passing', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'passes-yards-gross' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        -- rushing
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 2, 'rushing', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'rushes-yards' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 2, 'rushing', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'rushes-yards' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        -- receiving
        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 3, 'receiving', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @away_key AND [column] = 'receptions-yards' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC

        INSERT INTO @team_leaders (category_order, category, team_key, player_key, value)
        SELECT TOP 3 3, 'receiving', team_key, player_key, value
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @seasonKey AND sub_season_type = 'season-regular' AND
               team_key = @home_key AND [column] = 'receptions-yards' AND player_key <> 'team'
         ORDER BY CAST(value AS FLOAT) DESC
    END
    
    
	UPDATE tl
	   SET tl.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	  FROM @team_leaders tl
	 INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = tl.player_key


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
		(
			SELECT
				(
					SELECT 'true' AS 'json:Array',
					       ac.category,
					   (
						   SELECT 'true' AS 'json:Array',
						          al.name, al.value
							 FROM @team_leaders AS al
							WHERE al.category = ac.category AND al.team_key = @away_key
							  FOR XML RAW('leaders'), TYPE
					   )
					  FROM @team_leaders AS ac
					 GROUP BY ac.category, ac.category_order
					 ORDER BY ac.category_order ASC
					   FOR XML RAW('away'), TYPE
				),
				(
					SELECT 'true' AS 'json:Array',
					       hc.category,
					   (
						   SELECT 'true' AS 'json:Array',
						          hl.name, hl.value
							 FROM @team_leaders AS hl
							WHERE hl.category = hc.category AND hl.team_key = @home_key
							  FOR XML RAW('leaders'), TYPE
					   )
					  FROM @team_leaders AS hc
					 GROUP BY hc.category, hc.category_order
					 ORDER BY hc.category_order ASC
					   FOR XML RAW('home'), TYPE
				)
           FOR XML PATH('team_leaders'), TYPE
		)
	   FOR XML RAW('root'), TYPE

    
    SET NOCOUNT OFF;
END


GO
