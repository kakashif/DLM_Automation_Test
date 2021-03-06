USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamStatistics_NHL_player_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamStatistics_NHL_player_XML]
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 09/12/2013
  -- Description: get NHL team player statistics
  -- Update: 06/23/2014 - John Lin - use SMG_Teams for abbr
  --         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         04/08/2015 - John Lin - new head shot logic
  --         10/21/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nhl')

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
    DECLARE @hockey TABLE
    (
        player_key VARCHAR(100),
        -- shared
        games_played INT,
        time_on_ice_secs INT,
        [minutes-played-per-game] VARCHAR(100),
        -- goaltending
        wins INT,
        losses INT,
        overtime_losses INT,
        goals_against INT,
        shots_against INT,
        shutouts INT,
        [goalie-qualify] INT,
        goals_against_average VARCHAR(100),
        -- goaltending calculation
        saves INT,
        [save-percentage] VARCHAR(100),
        -- defense
        goals_power_play INT,
        assists_power_play INT,
        goals_short_handed INT,
        assists_short_handed INT,
        penalty_minutes INT,
        [penalty-minutes-per-game] VARCHAR(100),
        shootouts_attempted INT,
        shootouts_scored INT,
        blocked_shots INT,
        hits INT,
        -- defense calculation
        [shootouts-percentage] VARCHAR(100),
        -- offense
        goals INT,
        assists INT,
        plus_minus INT,
        shots INT,
        game_winning_goals INT,
        faceoffs_won INT,
        faceoffs_lost INT,
        -- offense calculation
        points INT,
        [points-per-game] VARCHAR(100),
        [faceoffs-percentage] VARCHAR(100),
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

    IF (@category = 'goaltending')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('GOALTENDING', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('GOALTENDING', 'games_played', '', 'GP', 'Games Played', 3),
               ('GOALTENDING', 'wins', '', 'W', 'Wins', 4),
               ('GOALTENDING', 'losses', '', 'L', 'Losses', 5),
               ('GOALTENDING', 'overtime_losses', '', 'OTL', 'Overtime Losses', 6),
               ('GOALTENDING', 'goals_against_average', '', 'GAA', 'Goals Against Average', 7),
               ('GOALTENDING', 'goals_against', '', 'GA', 'Goals Against', 8),
               ('GOALTENDING', 'shots_against', '', 'SA', 'Shots Against', 9),
               ('GOALTENDING', 'saves', '', 'SV', 'Saves', 10),
               ('GOALTENDING', 'save-percentage', '', 'SV%', 'Save Percentage', 11),
               ('GOALTENDING', 'shutouts', '', 'SHO', 'Shutouts', 12)

        -- GOALTENDING
        INSERT INTO @hockey (player_key, games_played, time_on_ice_secs,
                             wins, losses, overtime_losses, goals_against_average, goals_against, shots_against,
                             shutouts, [goalie-qualify])
        SELECT p.player_key, ISNULL(games_played, 0), ISNULL(time_on_ice_secs, 0),
               ISNULL(wins, 0), ISNULL(losses, 0), ISNULL(overtime_losses, 0), ISNULL(goals_against_average, 0), ISNULL(goals_against, 0), ISNULL(shots_against, 0),
               ISNULL(shutouts, 0), ISNULL([goalie-qualify], 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, time_on_ice_secs,
                                                wins, losses, overtime_losses, goals_against_average, goals_against, shots_against,
                                                shutouts, [goalie-qualify])) AS p

		-- calculates if not present
		UPDATE @hockey
		   SET [saves] = (shots_against - goals_against),
		       goals_against_average = CAST(CAST(goals_against_average AS DECIMAL(6, 2)) AS VARCHAR)

		UPDATE @hockey
		   SET [save-percentage] = REPLACE(CAST(CAST((CAST(saves AS FLOAT) / shots_against) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
		 WHERE shots_against > 0
		   
        -- update goaltending
	    UPDATE h
	       SET h.position_regular = sr.position_regular
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = h.player_key

	    UPDATE h
	       SET h.name = sp.first_name + ' ' + sp.last_name
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = h.player_key

        -- delete no name
        DELETE @hockey
         WHERE name IS NULL
         
        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'GOALS AGAINST AVERAGE', player_key, name, position_regular, goals_against_average + ' GAA', 'GOALTENDING', 'goals-against-per-game'
          FROM @hockey
         WHERE [goalie-qualify] = '1'
         ORDER BY CONVERT(FLOAT, goals_against_average) ASC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SAVE PERCENTAGE', player_key, name, position_regular, [save-percentage] + ' SV%', 'GOALTENDING', 'save-percentage'
          FROM @hockey
         WHERE [goalie-qualify] = '1'
         ORDER BY CONVERT(FLOAT, [save-percentage]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'WINS', player_key, name, position_regular, CAST(wins AS VARCHAR) + ' W', 'GOALTENDING', 'wins'
          FROM @hockey
         ORDER BY wins DESC

        -- update leaders
        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('GOALTENDING', 'goaltending', 'goals-against-per-game')



        SELECT
        (
            SELECT 'GOALTENDING LEAGUE LEADERS' AS super_ribbon, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('losses', 'overtime_losses', 'goals_against_average', 'goals_against') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type],
                   (CASE
                       WHEN [column] IN ('goals-against-per-game', 'save-percentage') THEN 1
                       ELSE 0
                   END) AS qualify
              FROM @tables
             WHERE ribbon = 'GOALTENDING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('goaltending_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   games_played, wins, losses, overtime_losses,
                   goals_against_average + '|' + CAST([goalie-qualify] AS VARCHAR) AS goals_against_average,                   
                   goals_against, shots_against, [saves],
                   [save-percentage] + '|' + CAST([goalie-qualify] AS VARCHAR) AS [save-percentage],
                   shutouts
              FROM @hockey
             WHERE (wins + losses) > 0
             ORDER BY CONVERT(FLOAT, goals_against) DESC
                   FOR XML RAW('goaltending'), TYPE                   
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
    ELSE IF (@category = 'special-teams')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('SPECIAL TEAMS', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('SPECIAL TEAMS', 'games_played', '', 'GP', 'Games Played', 3),
               ('SPECIAL TEAMS', 'goals_power_play', 'Power Play', 'G', 'Power Play Goals', 4),
               ('SPECIAL TEAMS', 'assists_power_play', 'Power Play', 'A', 'Power Play Assists', 5),
               ('SPECIAL TEAMS', 'goals_short_handed', 'Short-Handed', 'G', 'Short-Handed Goals', 6),
               ('SPECIAL TEAMS', 'assists_short_handed', 'Short-Handed', 'A', 'Short-Handed Assists', 7),
               ('SPECIAL TEAMS', 'penalty_minutes', 'Penalties', 'PIM', 'Penalty Minutes', 8),
               ('SPECIAL TEAMS', 'penalty-minutes-per-game', 'Penalties', 'PIM/G', 'Penalty Minutes Per Game', 9),
               ('SPECIAL TEAMS', 'shootouts_attempted', 'Shootout', 'ATT', 'Shootout Attempts', 12),
               ('SPECIAL TEAMS', 'shootouts_scored', 'Shootout', 'G', 'Shootout Goals', 13),
               ('SPECIAL TEAMS', 'shootouts-percentage', 'Shootout', 'PCT', 'Shootout Percentage', 14),
               ('SPECIAL TEAMS', 'blocked_shots', 'Defense', 'BS', 'Blocked Shots', 18),
               ('SPECIAL TEAMS', 'hits', 'Defense', 'H', 'Hits', 19)

        -- SPECIAL TEAMS
        INSERT INTO @hockey (player_key, games_played, time_on_ice_secs, wins, losses,
                             goals_power_play, assists_power_play, goals_short_handed, assists_short_handed,
                             penalty_minutes, [penalty-minutes-per-game], shootouts_attempted, shootouts_scored, blocked_shots,hits)
        SELECT p.player_key, ISNULL(games_played, 0), ISNULL(time_on_ice_secs, 0), ISNULL(wins, 0), ISNULL(losses, 0),
               ISNULL(goals_power_play, 0), ISNULL(assists_power_play, 0), ISNULL(goals_short_handed, 0), ISNULL(assists_short_handed, 0),
               ISNULL(penalty_minutes, 0), ISNULL([penalty-minutes-per-game], 0), ISNULL(shootouts_attempted, 0), ISNULL(shootouts_scored, 0),
               ISNULL(blocked_shots, 0), ISNULL(hits, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, time_on_ice_secs, wins, losses,
                                                goals_power_play, assists_power_play, goals_short_handed, assists_short_handed,
                                                penalty_minutes, [penalty-minutes-per-game], shootouts_attempted, shootouts_scored, blocked_shots,hits)) AS p

		-- calculates if not present
		UPDATE @hockey
		   SET [shootouts-percentage] = REPLACE(CAST(CAST((CAST(shootouts_scored AS FLOAT) / shootouts_attempted) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
         WHERE shootouts_attempted > 0

        -- update special teams
	    UPDATE h
	       SET h.position_regular = sr.position_regular
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = h.player_key

	    UPDATE h
	       SET h.name = sp.first_name + ' ' + sp.last_name
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = h.player_key

        -- delete no name
        DELETE @hockey
         WHERE name IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'POWER PLAY GOALS', player_key, name, position_regular, CAST(goals_power_play AS VARCHAR) + ' PPG', 'SPECIAL TEAMS', 'goals_power_play'
          FROM @hockey
         ORDER BY goals_power_play DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SHORT-HANDED GOALS', player_key, name, position_regular, CAST(goals_short_handed AS VARCHAR) + ' SHG', 'SPECIAL TEAMS', 'goals_short_handed'
          FROM @hockey
         ORDER BY goals_short_handed DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'PENALTY MINUTES', player_key, name, position_regular, CAST(penalty_minutes AS VARCHAR) + ' PIM', 'SPECIAL TEAMS', 'penalty_minutes'
          FROM @hockey
         ORDER BY penalty_minutes ASC

        -- update leaders
        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('SPECIAL TEAMS', 'special', 'goals_power_play')

        SELECT
        (
            SELECT 'SPECIAL TEAMS LEAGUE LEADERS' AS super_ribbon, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('penalty_minutes', 'penalty-minutes-per-game') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'SPECIAL TEAMS' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('special_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   games_played, goals_power_play, assists_power_play, goals_short_handed, assists_short_handed,
                   penalty_minutes, [penalty-minutes-per-game], shootouts_attempted, shootouts_scored,
                   [shootouts-percentage], blocked_shots, hits
              FROM @hockey
             WHERE (wins + losses) = 0
             ORDER BY goals_power_play DESC
               FOR XML RAW('special'), TYPE
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
               ('OFFENSE', 'minutes-played-per-game', '', 'TOI', 'Time on Ice Per Game', 4),
               ('OFFENSE', 'goals', '', 'G', 'Goals', 5),
               ('OFFENSE', 'assists', '', 'A', 'Assists', 6),
               ('OFFENSE', 'points', '', 'PTS', 'Points', 7),
               ('OFFENSE', 'plus_minus', '', '+/-', 'Plus/Minus', 8),
               ('OFFENSE', 'points-per-game', '', 'PTS/G', 'Points Per Game', 9),
               ('OFFENSE', 'shots', '', 'SOG', 'Shots On Goal', 10),
               ('OFFENSE', 'game_winning_goals', '', 'GWG', 'Game Winning Goals', 11),
               ('OFFENSE', 'faceoffs_won', '', 'FW', 'Faceoff Wins', 12),
               ('OFFENSE', 'faceoffs_lost', '', 'FL', 'Faceoff Losses', 13),
               ('OFFENSE', 'faceoffs-percentage', '', 'FW%', 'Faceoff Win %', 14)

        -- OFFENSE
        INSERT INTO @hockey (player_key, games_played, time_on_ice_secs, wins, losses,
                             goals, assists, plus_minus, shots, game_winning_goals, faceoffs_won, faceoffs_lost)
        SELECT p.player_key, ISNULL(games_played, 0), ISNULL(time_on_ice_secs, 0), ISNULL(wins, 0), ISNULL(losses, 0),
               ISNULL(goals, 0), ISNULL(assists, 0), ISNULL(plus_minus, 0), ISNULL(shots, 0), ISNULL(game_winning_goals, 0), ISNULL(faceoffs_won, 0), ISNULL(faceoffs_lost, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, time_on_ice_secs, wins, losses,
                                                goals, assists, plus_minus, shots, game_winning_goals, faceoffs_won, faceoffs_lost)) AS p

		-- calculates if not present
		UPDATE @hockey
		   SET points = (goals + assists),
		   	   [minutes-played-per-game] = CAST(((time_on_ice_secs / games_played ) / 60) AS VARCHAR) + ':' +
		                                   CASE
		                                       WHEN ((time_on_ice_secs / games_played ) % 60) > 9 THEN CAST(((time_on_ice_secs / games_played ) % 60) AS VARCHAR)
		                                       ELSE '0' + CAST(((time_on_ice_secs / games_played ) % 60) AS VARCHAR)
		                                   END

		UPDATE @hockey
		   SET [points-per-game] = CAST(CAST((CAST(points AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR)

		UPDATE @hockey
		   SET [faceoffs-percentage] = REPLACE(CAST(CAST((CAST(faceoffs_won AS FLOAT) / (faceoffs_won + faceoffs_lost)) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
		 WHERE (faceoffs_won + faceoffs_lost) > 0

        -- update special teams
	    UPDATE h
	       SET h.position_regular = sr.position_regular
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = h.player_key

	    UPDATE h
	       SET h.name = sp.first_name + ' ' + sp.last_name
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = h.player_key

        -- delete no name
        DELETE @hockey
         WHERE name IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'POINTS', player_key, name, position_regular, CAST(points AS VARCHAR) + ' PTS', 'OFFENSE', 'points'
          FROM @hockey
         ORDER BY points DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'GOALS', player_key, name, position_regular, CAST(goals AS VARCHAR) + ' G', 'OFFENSE', 'goals'
          FROM @hockey
         ORDER BY goals DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'plus_minus', player_key, name, position_regular, CAST(plus_minus AS VARCHAR) + ' +/-', 'OFFENSE', 'plus_minus'
          FROM @hockey
         ORDER BY plus_minus DESC

        -- update leaders
        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('OFFENSE', 'offense', 'points')


        SELECT
        (
            SELECT 'OFFENSIVE LEAGUE LEADERS' AS super_ribbon, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('faceoffs_lost') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
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
                   games_played, [minutes-played-per-game], goals, assists, points, plus_minus, [points-per-game],
                   shots, game_winning_goals, faceoffs_won, faceoffs_lost, [faceoffs-percentage]
              FROM @hockey
             WHERE (wins + losses) = 0
             ORDER BY points DESC
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
