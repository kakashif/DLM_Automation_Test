USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Statistics_basketball_player_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Statistics_basketball_player_XML]
   @leagueName    VARCHAR(100),
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/02/2013
  -- Description: get WNBA player statistics
  -- Update: 06/23/2014 - John Lin - use SMG_Teams for abbr
  --         02/20/2015 - ikenticus - migrating to SMG_Statistics, replacing baseball crap with basketball
  --         04/08/2015 - John Lin - new head shot logic
  --         07/22/2015 - John Lin - STATS migration
  --         09/11/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    
    DECLARE @stats TABLE
    (
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (player_key, [column], value)
    SELECT player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND team_key = @teamKey AND player_key <> 'team' AND category = 'feed'

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
        player_key VARCHAR(100),
        -- shared
        games_played INT,
        seconds_played INT,
        [minutes-played-per-game] VARCHAR(100),
        -- defense
        fouls_personal INT,
        rebounds_offensive INT,
        rebounds_defensive INT,
        steals INT,
        blocks INT,
        -- defense calculation
        [fouls-personal-per-game] VARCHAR(100),
        [total-rebounds] INT,
        [rebounds-per-game] VARCHAR(100),
        [rebounds-offensive-per-game] VARCHAR(100),
        [rebounds-defensive-per-game] VARCHAR(100),
        [steals-per-game] VARCHAR(100),
        [blocks-per-game] VARCHAR(100),
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
        [three-point-field-goals-percentage] VARCHAR(100),
        -- reference NULL
        position_regular VARCHAR(100),
        name VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        player_key        VARCHAR(100),
        name              VARCHAR(100),
        uniform_number    VARCHAR(100),
        position_regular  VARCHAR(100),
        ribbon            VARCHAR(100),
        value             VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100),
        head_shot         VARCHAR(100)
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100),
        [column]    VARCHAR(100),
        display     VARCHAR(100),
        [sort]      VARCHAR(100) 
    )    
    DECLARE @abbr VARCHAR(100)
    DECLARE @rgb VARCHAR(100)
    
    SELECT @abbr = team_abbreviation, @rgb = rgb
      FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @teamKey

    IF (@category = 'defense')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('DEFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('DEFENSE', 'games_played', '', 'GP', 'Games Played', 3),
               ('DEFENSE', 'minutes-played-per-game', '', 'M/G', 'Minutes Per Game', 4),
               ('DEFENSE', 'rebounds-offensive-per-game', 'REBOUNDS', 'OR/G', 'Offensive Rebounds Per Game', 5),
               ('DEFENSE', 'rebounds-defensive-per-game', 'REBOUNDS', 'DR/G', 'Defensive Rebounds Per Game', 6),
               ('DEFENSE', 'rebounds-per-game', 'REBOUNDS', 'REB/G', 'Rebounds Per Game', 7),
               ('DEFENSE', 'rebounds', 'REBOUNDS', 'REB', 'Total Rebounds', 8),
               ('DEFENSE', 'steals-per-game', 'STEALS', 'S/G', 'Steals Per Game', 9),
               ('DEFENSE', 'steals', 'STEALS', 'STL', 'Total Steals', 10),
               ('DEFENSE', 'blocks', 'BLOCKS', 'BLK', 'Blocks Per Game', 11),
               ('DEFENSE', 'blocks-per-game', 'BLOCKS', 'B/G', 'Total Blocks', 12),
               ('DEFENSE', 'fouls_personal', 'PERSONAL FOULS', 'PF', 'Losses', 13),
               ('DEFENSE', 'fouls-personal-per-game', 'PERSONAL FOULS', 'PF/G', 'Saves', 14)
              
        INSERT INTO @basketball (player_key, games_played, seconds_played, fouls_personal,
                                 rebounds_offensive, rebounds_defensive, steals, blocks)
        SELECT p.player_key, ISNULL(games_played, 0), ISNULL(seconds_played, 0), ISNULL(fouls_personal, 0),
               ISNULL(rebounds_offensive, 0), ISNULL(rebounds_defensive, 0), ISNULL(steals, 0), ISNULL(blocks, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, seconds_played, fouls_personal,
                                                rebounds_offensive, rebounds_defensive, steals, blocks)) AS p

		-- calculates if not present
		UPDATE @basketball
		   SET [total-rebounds] = rebounds_offensive + rebounds_defensive,
		       [minutes-played-per-game] = CAST(((seconds_played / games_played ) / 60) AS VARCHAR) + ':' +
		                                   CASE
		                                       WHEN ((seconds_played / games_played ) % 60) > 9 THEN CAST(((seconds_played / games_played ) % 60) AS VARCHAR)
		                                       ELSE '0' + CAST(((seconds_played / games_played ) % 60) AS VARCHAR)
		                                   END

		UPDATE @basketball
		   SET [fouls-personal-per-game] = CAST((CAST(fouls_personal AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [rebounds-per-game] = CAST((CAST([total-rebounds] AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [rebounds-offensive-per-game] = CAST((CAST(rebounds_offensive AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [rebounds-defensive-per-game] = CAST((CAST(rebounds_defensive AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [steals-per-game] = CAST((CAST(steals AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

		UPDATE @basketball
		   SET [blocks-per-game] = CAST((CAST(blocks AS FLOAT) / games_played) AS DECIMAL(6, 2))
		 WHERE games_played > 0

        -- update defense
	    UPDATE b
	       SET b.position_regular = sr.position_regular
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = b.player_key

	    UPDATE b
	       SET b.name = sp.first_name + ' ' + sp.last_name
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = b.player_key

        -- delete no name
        DELETE @basketball
         WHERE name IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'REBOUNDS', player_key, name, position_regular, [rebounds-per-game] + ' REB/G', 'DEFENSE', 'rebounds-per-game'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [rebounds-per-game]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'BLOCKS', player_key, name, position_regular, [blocks-per-game] + ' B/G', 'DEFENSE', 'blocks-per-game'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [blocks-per-game]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'STEALS', player_key, name, position_regular, [steals-per-game] + ' S/G', 'DEFENSE', 'steals-per-game'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [steals-per-game]) DESC

        -- update leaders
        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = @teamKey AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- CON HACK
        UPDATE @leaders
           SET head_shot = REPLACE(head_shot, '/CON/', '/CON_/')

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('DEFENSE', 'defense', 'rebounds-per-game')



        SELECT
        (
            SELECT 'DEFENSE LEAGUE LEADERS' AS super_ribbon, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('fouls_personal', 'fouls-personal-per-game') THEN 'asc,desc'
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
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   games_played, [minutes-played-per-game], [fouls-personal-per-game],
                   [rebounds-offensive-per-game], [rebounds-defensive-per-game], rebounds_defensive, [rebounds-per-game], [total-rebounds],
                   [steals-per-game], steals, blocks, [blocks-per-game], fouls_personal
              FROM @basketball
             WHERE games_played > 0
             ORDER BY CONVERT(FLOAT, [rebounds-per-game]) DESC
                   FOR XML RAW('defense'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
    ELSE
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('OFFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('OFFENSE', 'games_played', '', 'GP', 'Games Played', 3),
               ('OFFENSE', 'minutes-played-per-game', '', 'M/G', 'Minutes Per Game', 4),
               ('OFFENSE', 'points', '', 'PTS', 'Points', 5),
               ('OFFENSE', 'points-per-game', '', 'PTS/G', 'Points Per Game', 6),
               ('OFFENSE', 'field_goals_made', 'SCORING', 'FGM', 'Field Goals Made', 7),
               ('OFFENSE', 'field_goals_attempted', 'SCORING', 'FGA', 'Field Goals Attempted', 8),
               ('OFFENSE', 'field-goals-percentage', 'SCORING', 'FG%', 'Field Goal Percentage', 9),
               ('OFFENSE', 'three_point_field_goals_made', 'SCORING', '3PM', '3 Point Field Goals Made', 10),
               ('OFFENSE', 'three_point_field_goals_attempted', 'SCORING', '3PA', '3 Point Field Goals Attempted', 11),
               ('OFFENSE', 'three-point-field-goals-percentage', 'SCORING', '3PT%', '3 Point Field Goal Percentage', 12),
               ('OFFENSE', 'free_throws_made', 'FREE THROWS', 'FTM', 'Free Throws Made', 13),
               ('OFFENSE', 'free_throws_attempted', 'FREE THROWS', 'FTA', 'Free Throws Attempted', 14),
               ('OFFENSE', 'free-throws-percentage', 'FREE THROWS', 'FT%', 'Free Throw Percentage', 15),
               ('OFFENSE', 'assists', 'ASSISTS', 'AST', 'Asists', 16),
               ('OFFENSE', 'assists-per-game', 'ASSISTS', 'AP/G', 'Asists Per Game', 17),
               ('OFFENSE', 'turnovers', 'TURNOVERS', 'TO', 'Turnovers', 18),
               ('OFFENSE', 'turnovers-per-game', 'TURNOVERS', 'TO/G', 'Turnovers Per Game', 19)

        INSERT INTO @basketball (player_key, games_played, seconds_played, points, assists, turnovers,
                                 field_goals_made, field_goals_attempted, free_throws_made, free_throws_attempted,
                                 three_point_field_goals_made, three_point_field_goals_attempted)
        SELECT p.player_key, ISNULL(games_played, 0), ISNULL(seconds_played, 0), ISNULL(points, 0), ISNULL(assists, 0), ISNULL(turnovers, 0),
               ISNULL(field_goals_made, 0), ISNULL(field_goals_attempted, 0), ISNULL(free_throws_made, 0), ISNULL(free_throws_attempted, 0),
               ISNULL(three_point_field_goals_made, 0), ISNULL(three_point_field_goals_attempted, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, seconds_played, points, assists, turnovers,
                                                field_goals_made, field_goals_attempted, free_throws_made, free_throws_attempted,
                                                three_point_field_goals_made, three_point_field_goals_attempted)) AS p

		-- calculates if not present
		UPDATE @basketball
		   SET [minutes-played-per-game] = CAST(((seconds_played / games_played ) / 60) AS VARCHAR) + ':' +
		                                   CASE
		                                       WHEN ((seconds_played / games_played ) % 60) > 9 THEN CAST(((seconds_played / games_played ) % 60) AS VARCHAR)
		                                       ELSE '0' + CAST(((seconds_played / games_played ) % 60) AS VARCHAR)
		                                   END

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

        -- update defense
	    UPDATE b
	       SET b.position_regular = sr.position_regular
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = b.player_key

	    UPDATE b
	       SET b.name = sp.first_name + ' ' + sp.last_name
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = b.player_key

        -- delete no name
        DELETE @basketball
         WHERE name IS NULL
         
        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'POINTS PER GAME', player_key, name, position_regular, [points-per-game] + ' PTS/G', 'OFFENSE', 'points-per-game'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [points-per-game]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'ASSIST PER GAME', player_key, name, position_regular, [assists-per-game] + ' AST/G', 'OFFENSE', 'assists-per-game'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [assists-per-game]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'FIELD GOAL %', player_key, name, position_regular, [field-goals-percentage] + ' FG%', 'OFFENSE', 'field-goals-percentage'
          FROM @basketball
         ORDER BY CONVERT(FLOAT, [field-goals-percentage]) DESC

        -- update leaders
        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = @teamKey AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- CON HACK
        UPDATE @leaders
           SET head_shot = REPLACE(head_shot, '/CON/', '/CON_/')

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('OFFENSE', 'offense', 'points-per-game')



        SELECT
        (
            SELECT 'OFFENSE LEAGUE LEADERS' AS super_ribbon, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
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
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   games_played, [minutes-played-per-game], points, [points-per-game], field_goals_made,
                   field_goals_attempted, [field-goals-percentage], three_point_field_goals_made, three_point_field_goals_attempted,
                   [three-point-field-goals-percentage], free_throws_made, free_throws_attempted, [free-throws-percentage], assists,
                   [assists-per-game], turnovers, [turnovers-per-game]
              FROM @basketball
             WHERE games_played > 0
             ORDER BY CONVERT(FLOAT, [points-per-game]) DESC
                   FOR XML RAW('offense'), TYPE                   
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
END

GO
