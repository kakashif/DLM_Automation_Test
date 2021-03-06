USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Statistics_basketball_team_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Statistics_basketball_team_XML]
   @leagueName    VARCHAR(100),
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/02/2013
  -- Description: get WNBA team statistics
  -- Update: 01/08/2015 - John Lin - change team_key from league-average to l.wnba.com
  --         02/20/2015 - ikenticus - migrating to SMG_Statistics, replacing baseball crap with basketball
  --         07/22/2015 - John Lin - STATS migration
  --         09/14/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    
    DECLARE @stats TABLE
    (
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    INSERT INTO @stats (category, [column], value)
    SELECT category, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND team_key = @teamKey AND player_key = 'team'

    DECLARE @tables TABLE
    (
        ribbon VARCHAR(100),
        [column] VARCHAR(100),
        sub_ribbon VARCHAR(100),
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [order] INT
    )
    DECLARE @basketball TABLE
    (
        category VARCHAR(100),
        games_played VARCHAR(100),
        -- defense
        steals_against INT,
        blocks_against INT,
        fouls_personal_against INT,
        fouls_technical_against INT,
        rebounds_team_against INT,
        rebounds_defensive_against INT,
        rebounds_offensive_against INT,
        -- defense calculation
        [steals-against-per-game] VARCHAR(100),
        [blocks-against-per-game] VARCHAR(100),
        [rebounds-team-against-per-game] VARCHAR(100),
        [rebounds-offensive-against-per-game] VARCHAR(100),
        [rebounds-defensive-against-per-game] VARCHAR(100),
        -- offense
        points INT,
        assists INT,
        turnovers INT,
        field_goals_made INT,
        field_goals_attempted INT,
        free_throws_made INT,
        free_throws_attempted INT,
        three_point_field_goals_made INT,
        three_point_field_goals_attempted INT,
        -- offense calculation
        [points-per-game] VARCHAR(100),
        [assists-per-game] VARCHAR(100),
        [turnovers-per-game] VARCHAR(100),
        [field-goals-percentage] VARCHAR(100),
        [free-throws-percentage] VARCHAR(100),
        [three-point-field-goals-percentage] VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        ribbon           VARCHAR(100), 
        [rank]           VARCHAR(100),
        value            VARCHAR(100),
        reference_ribbon VARCHAR(100),
        reference_column VARCHAR(100)
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        sub_ribbon VARCHAR(100), 
        player_key VARCHAR(100),
        name       VARCHAR(100)
    )
    -- name
    DECLARE @name VARCHAR(100)
    DECLARE @rgb VARCHAR(100)
        
    SELECT @name = team_last, @rgb = rgb
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @teamKey

    IF (@category = 'defense')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('DEFENSE', 'name', '', 'NAME', '', 2),
               ('DEFENSE', 'games_played', '', 'GP', 'Games Played', 3),
               ('DEFENSE', 'rebounds-offensive-against-per-game', 'REBOUNDS', 'OR/G', 'Offensive Rebounds Per Game', 4),
               ('DEFENSE', 'rebounds-defensive-against-per-game', 'REBOUNDS', 'DEF/G', 'Defensive Rebounds Per Game', 5),
               ('DEFENSE', 'rebounds-team-against-per-game', 'REBOUNDS', 'R/G', 'Rebounds Per Game', 6),
               ('DEFENSE', 'rebounds_team_against', 'REBOUNDS', 'REB', 'Total Rebounds', 7),
               ('DEFENSE', 'steals-against-per-game', 'STEALS', 'STL/G', 'Steals Per Game', 8),
               ('DEFENSE', 'steals_against', 'STEALS', 'STL', 'Total Steals', 9),
               ('DEFENSE', 'blocks-against-per-game', 'BLOCKS', 'B/G', 'Blocks Per Game', 10),
               ('DEFENSE', 'blocks_against', 'BLOCKS', 'BLK', 'Total Blocks', 11),
               ('DEFENSE', 'fouls_personal_against', 'PENALTIES', 'IDEF', 'Total Personal Fouls', 15),
               ('DEFENSE', 'fouls_technical_against', 'PENALTIES', 'TF', 'Total Technical Fouls', 16)
              
        INSERT INTO @basketball (games_played, steals_against, blocks_against, fouls_personal_against, fouls_technical_against,
                                 rebounds_team_against, rebounds_defensive_against, rebounds_offensive_against)                 
        SELECT ISNULL(games_played, 0), ISNULL(steals_against, 0), ISNULL(blocks_against, 0),
               ISNULL(fouls_personal_against, 0), ISNULL(fouls_technical_against, 0),
               ISNULL(rebounds_team_against, 0), ISNULL(rebounds_defensive_against, 0), ISNULL(rebounds_offensive_against, 0)
          FROM (SELECT [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, steals_against, blocks_against, fouls_personal_against, fouls_technical_against,
                                                rebounds_team_against, rebounds_defensive_against, rebounds_offensive_against)) AS p

		-- calculates if not present
    	UPDATE @basketball
		   SET [steals-against-per-game] = CAST((CAST(steals_against AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

    	UPDATE @basketball
		   SET [blocks-against-per-game] = CAST((CAST(blocks_against AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

    	UPDATE @basketball
		   SET [rebounds-team-against-per-game] = CAST((CAST(rebounds_team_against AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

    	UPDATE @basketball
		   SET [rebounds-offensive-against-per-game] = CAST((CAST(rebounds_offensive_against AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

    	UPDATE @basketball
		   SET [rebounds-defensive-against-per-game] = CAST((CAST(rebounds_defensive_against AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'REBOUNDS', [rebounds-team-against-per-game] + ' R/G', 'DEFENSE', 'rebounds-team-against-per-game'
          FROM @basketball
         ORDER BY CAST([rebounds-team-against-per-game] AS FLOAT) DESC
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'BLOCKS', [blocks-against-per-game] + ' B/G', 'DEFENSE', 'blocks-against-per-game'
          FROM @basketball
         ORDER BY CAST([blocks-against-per-game] AS FLOAT) DESC
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'STEALS', [steals-against-per-game] + ' STL/G', 'DEFENSE', 'steals-against-per-game'
          FROM @basketball
         ORDER BY CAST([steals-against-per-game] AS FLOAT) DESC

/*
        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'REBOUNDS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'rebounds-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'BLOCKS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'blocks-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'STEALS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'steals-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC
*/

        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('DEFENSE', 'defense')

        SELECT
        (
            SELECT 'DEFENSE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   (CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 2) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 2) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 2) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END) AS [rank], value, reference_ribbon, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('fouls_personal_against', 'fouls_technical_against') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('defense_column'), TYPE
        ),
        (
            SELECT games_played, [rebounds-offensive-against-per-game], [rebounds-defensive-against-per-game], [rebounds-team-against-per-game],
                   rebounds_team_against, [steals-against-per-game], steals_against, [blocks-against-per-game], blocks_against, fouls_personal_against,
                   fouls_technical_against
              FROM @basketball
             ORDER BY CAST([rebounds-team-against-per-game] AS FLOAT) ASC
               FOR XML RAW('defense'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   games_played, [rebounds-offensive-against-per-game], [rebounds-defensive-against-per-game], [rebounds-team-against-per-game],
                   rebounds_team_against, [steals-against-per-game], steals_against, [blocks-against-per-game], blocks_against, fouls_personal_against,
                   fouls_technical_against
              FROM @basketball
             ORDER BY category ASC
               FOR XML RAW('defense'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
    ELSE
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('OFFENSE', 'name', '', 'NAME', '', 2),
               ('OFFENSE', 'games_played', '', 'GP', 'Games Played', 3),
               ('OFFENSE', 'points', '', 'PTS', 'Points', 4),
               ('OFFENSE', 'points-per-game', '', 'P/G', 'Points Per Game', 5),
               ('OFFENSE', 'field_goals_made', 'SCORING', 'FGM', 'Field Goals Made', 6),
               ('OFFENSE', 'field_goals_attempted', 'SCORING', 'FGA', 'Field Goals Attempted', 7),
               ('OFFENSE', 'field-goals-percentage', 'SCORING', 'FG%', 'Field Goal Percentage', 8),
               ('OFFENSE', 'three_point_field_goals_made', 'SCORING', '3PM', '3 Point Field Goals Made', 9),
               ('OFFENSE', 'three_point_field_goals_attempted', 'SCORING', '3PA', '3 Point Field Goals Attempted', 10),
               ('OFFENSE', 'three-point-field-goals-percentage', 'SCORING', '3PT%', '3 Point Field Goal Percentage', 11),
               ('OFFENSE', 'free_throws_made', 'FREE THROWS', 'FTM', 'Free Throws Made', 12),
               ('OFFENSE', 'free_throws_attempted', 'FREE THROWS', 'FTA', 'Free Throws Attempted', 13),
               ('OFFENSE', 'free-throws-percentage', 'FREE THROWS', 'FT%', 'Free Throw Percentage', 14),
               ('OFFENSE', 'assists', 'ASSISTS', 'AST', 'Asists', 15),
               ('OFFENSE', 'assists-per-game', 'ASSISTS', 'AST/G', 'Asists Per Game', 16),
               ('OFFENSE', 'turnovers', 'TURNOVERS', 'TO', 'Turnovers', 17),
               ('OFFENSE', 'turnovers-per-game', 'TURNOVERS', 'TO/G', 'Turnovers Per Game', 18)
              
        INSERT INTO @basketball (games_played, points, assists, turnovers,
                                 field_goals_made, field_goals_attempted, free_throws_made, free_throws_attempted,
                                 three_point_field_goals_made, three_point_field_goals_attempted)
        SELECT ISNULL(games_played, 0), ISNULL(points, 0), ISNULL(assists, 0), ISNULL(turnovers, 0),
               ISNULL(field_goals_made, 0), ISNULL(field_goals_attempted, 0), ISNULL(free_throws_made, 0), ISNULL(free_throws_attempted, 0),
               ISNULL(three_point_field_goals_made, 0), ISNULL(three_point_field_goals_attempted, 0)
          FROM (SELECT [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, points, assists, turnovers,
                                                field_goals_made, field_goals_attempted, free_throws_made, free_throws_attempted,
                                                three_point_field_goals_made, three_point_field_goals_attempted)) AS p

		-- calculates if not present
		UPDATE @basketball
		   SET [points-per-game] = CAST((CAST(points AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

        UPDATE @basketball
           SET [field-goals-percentage] = CAST((100 * CAST(field_goals_made AS FLOAT) / field_goals_attempted) AS DECIMAL(4, 1))
         WHERE field_goals_attempted > 0

        UPDATE @basketball
           SET [three-point-field-goals-percentage] = CAST((100 * CAST(three_point_field_goals_made AS FLOAT) / three_point_field_goals_attempted) AS DECIMAL(4, 1))
         WHERE three_point_field_goals_attempted > 0

        UPDATE @basketball
           SET [free-throws-percentage] = CAST((100 * CAST(free_throws_made AS FLOAT) / free_throws_attempted) AS DECIMAL(4, 1))
         WHERE free_throws_attempted > 0
         
		UPDATE @basketball
		   SET [assists-per-game] = CAST((CAST(assists AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [turnovers-per-game] = CAST((CAST(turnovers AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'POINTS', CAST(points AS VARCHAR) + ' PTS', 'OFFENSE', 'points'
          FROM @basketball
         ORDER BY points DESC
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'ASSISTS', CAST(assists AS VARCHAR) + ' AST', 'OFFENSE', 'assists'
          FROM @basketball
         ORDER BY assists DESC
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 'FIELD GOAL PERCENTAGE', [field-goals-percentage] + ' FG%', 'OFFENSE', 'field-goals-percentage'
          FROM @basketball
         ORDER BY CAST([field-goals-percentage] AS FLOAT) DESC         

/*
        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'POINTS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'points-scored-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'ASSISTS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'assists-total-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'FIELD GOAL PERCENTAGE', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'field-goals-percentage' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC
*/
            
        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('OFFENSE', 'offense')

        SELECT
        (
            SELECT 'OFFENSE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   (CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 2) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 2) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 2) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END) AS [rank], value, reference_ribbon, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('turnovers', 'turnovers-per-game') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('offense_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   games_played, points, [points-per-game], field_goals_made, field_goals_attempted, [field-goals-percentage],
                   three_point_field_goals_made, three_point_field_goals_attempted, [three-point-field-goals-percentage],
                   free_throws_made, free_throws_attempted, [free-throws-percentage], assists, [assists-per-game], turnovers, [turnovers-per-game]
              FROM @basketball
             ORDER BY category ASC
               FOR XML RAW('offense'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
END

GO
