USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStatistics_NHL_team_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStatistics_NHL_team_XML]
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 09/12/2013
  -- Description: get NHL league team statistics
  -- Update: 10/21/2013 - John Lin - use team slug
  --         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
  --         06/05/2015 - ikenticus - replacing hard-coded league_key with function for non-xmlteam results
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nhl')

    DECLARE @stats TABLE
    (
        team_key  VARCHAR(100),
        [column]  VARCHAR(100), 
        value     VARCHAR(100),
        affiliate INT DEFAULT 0
    )
    INSERT INTO @stats (team_key, [column], value)
    SELECT team_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND player_key = 'team' AND category = 'feed'

    IF (@affiliation <> 'all')
    BEGIN
        SELECT @affiliation = conference_key
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND SportsEditDb.dbo.SMG_fnSlugifyName(conference_display) = @affiliation
         
        UPDATE s
           SET s.affiliate = 1
          FROM @stats s
         INNER JOIN dbo.SMG_Teams t
            ON t.team_key = s.team_key AND t.conference_key = @affiliation

        DELETE @stats
         WHERE affiliate = 0
    END

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
        team_key VARCHAR(100),
        games_played INT,
        -- defense
        goals_against INT,
        goals_overtime_against INT,
        shots_against INT,
        shots_overtime_against INT,
        shutouts_against INT,
        -- defense calculations
        [total-goals-against] INT,
        [total-goals-against-per-game] VARCHAR(100),
        [total-shots-against] INT,
        [total-shots-against-per-game] VARCHAR(100),        
        -- special teams
        power_plays INT,
        goals_power_play INT,
        power_plays_against INT,
        goals_power_play_against INT,
        faceoff_total_wins INT,
        faceoff_total_losses INT,
        penalty_minutes INT,
        -- special teams calculations
        [goals-power-play-percentage] VARCHAR(100),
        [goals-power-play-against-percentage] VARCHAR(100),
        [faceoff-total-wins-percentage] VARCHAR(100),
        [penalty-minutes-per-game] VARCHAR(100),
        -- offense
        goals INT,
        goals_overtime INT,
        shots INT,
        shots_overtime INT,
        shutouts INT,
        -- offense calculations
        [total-goals] INT,
        [total-goals-per-game] VARCHAR(100),
        [total-shots] INT,
        [total-shots-per-game] VARCHAR(100),        
        -- reference NULL
        team VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        team_key          VARCHAR(100),
        team_logo         VARCHAR(100),
        team_rgb          VARCHAR(100),
        team_link         VARCHAR(100),
        ribbon            VARCHAR(100), 
        name              VARCHAR(100),
        abbr              VARCHAR(100),
        value             VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100)
    )
    DECLARE @teams TABLE
    (
        sub_ribbon VARCHAR(100),
        team_key   VARCHAR(100), 
        name       VARCHAR(100)
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100),
        [column]    VARCHAR(100),
        display     VARCHAR(100),
        [sort]      VARCHAR(100) 
    )
    
    IF (@category = 'defense')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('DEFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('DEFENSE', 'games_played', '', 'GP', 'Games Played', 3),               
               ('DEFENSE', 'goals_against', 'Goals Allowed', 'RGA', 'Regulation Goals Allowed', 4),
               ('DEFENSE', 'goals_overtime_against', 'Goals Allowed', 'OGA', 'Overtime Goals Allowed', 5),               
               ('DEFENSE', 'total-goals-against', 'Goals Allowed', 'GA', 'Goals Allowed', 6),
               ('DEFENSE', 'total-goals-against-per-game', 'Goals Allowed', 'GA/G', 'Goals Allowed Per Game', 7),
               ('DEFENSE', 'shots_against', 'Shots Allowed', 'RSA', 'Regulation Shots Allowed', 8),
               ('DEFENSE', 'shots_overtime_against', 'Shots Allowed', 'OSA', 'Overtime Shots Allowed', 9),               
               ('DEFENSE', 'total-shots-against', 'Shots Allowed', 'SA', 'Shots Allowed', 10),
               ('DEFENSE', 'total-shots-against-per-game', 'Shots Allowed', 'SA/G', 'Shots Allowed Per Game', 11),
               ('DEFENSE', 'shutouts_against', '', 'SOA', 'Shutouts Allowed', 12)
              
        INSERT INTO @hockey (team_key, games_played, goals_against, goals_overtime_against, shots_against, shots_overtime_against, shutouts_against)
        SELECT p.team_key, ISNULL(games_played, 0),
               ISNULL(goals_against, 0), ISNULL(goals_overtime_against, 0), ISNULL(shots_against, 0), ISNULL(shots_overtime_against, 0), ISNULL(shutouts_against, 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, goals_against, goals_overtime_against, shots_against, shots_overtime_against, shutouts_against)) AS p

        -- calculations
        UPDATE @hockey
           SET [total-goals-against] = (goals_against + goals_overtime_against),
               [total-shots-against] = (shots_against + shots_overtime_against)

        UPDATE @hockey
           SET [total-goals-against-per-game] = CAST(CAST((CAST([total-goals-against] AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR),
               [total-shots-against-per-game] = CAST(CAST((CAST([total-shots-against] AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR)

        -- leaders
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'GOALS ALLOWED', CAST([total-goals-against] AS VARCHAR) + ' GA', 'DEFENSE', 'total-goals-against'
          FROM @hockey
         ORDER BY [total-goals-against] ASC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'SHOTS ALLOWED PER GAME', [total-shots-against-per-game] + ' SA/G', 'DEFENSE', 'total-shots-against-per-game'
          FROM @hockey
         ORDER BY CAST([total-shots-against-per-game] AS FLOAT) ASC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'SHUTOUTS ALLOWED', CAST(shutouts_against AS VARCHAR) + ' SOA', 'DEFENSE', 'shutouts_against'
          FROM @hockey
         ORDER BY shutouts_against DESC

        UPDATE l
           SET l.team_logo = dbo.SMG_fnTeamLogo('nhl', st.team_abbreviation, '80'),
               l.team_rgb = st.rgb, l.team_link = '/sports/nhl/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'GOALS ALLOWED', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'GOALS ALLOWED')
         ORDER BY[total-goals-against] ASC          

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'SHOTS ALLOWED PER GAME', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'SHOTS ALLOWED PER GAME')
         ORDER BY CAST([total-shots-against-per-game] AS FLOAT) ASC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'SHUTOUTS ALLOWED', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'SHUTOUTS ALLOWED')
         ORDER BY shutouts_against DESC

	    UPDATE l
	       SET l.name = st.team_last, l.abbr = st.team_abbreviation
	      FROM @leaders l
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

	    UPDATE t
	       SET t.name = st.team_last
	      FROM @teams t
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = t.team_key AND st.season_key = @seasonKey

	    UPDATE h
	       SET h.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = h.team_key AND st.season_key = @seasonKey

        DELETE @hockey
         WHERE team IS NULL
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('DEFENSE', 'defense', 'total-goals-against')


        SELECT
        (
            SELECT 'DEFENSIVE LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, team_link,
                   team_key, name, abbr, ribbon, value, reference_ribbon, reference_column,
                   (
                       SELECT team_key, name
                        FROM @teams
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('team'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('defense_column'), TYPE
        ),
        (
            SELECT team, games_played, goals_against, goals_overtime_against, [total-goals-against], [total-goals-against-per-game],
                   shots_against, shots_overtime_against, [total-shots-against], [total-shots-against-per-game], shutouts_against
              FROM @hockey
             ORDER BY [total-goals-against] ASC
               FOR XML RAW('defense'), TYPE
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
        VALUES ('SPECIAL TEAMS', 'team', '', 'TEAM', 'Team', 2),
               ('SPECIAL TEAMS', 'games_played', '', 'GP', 'Games Played', 3),              
               ('SPECIAL TEAMS', 'power_plays', 'Power Play', 'PP', 'Power Play', 5),
               ('SPECIAL TEAMS', 'goals_power_play', 'Power Play', 'PPG', 'Power Play Goals', 6),
               ('SPECIAL TEAMS', 'goals-power-play-percentage', 'Power Play', 'PCT', 'Power Play Goals Percentage', 7),
               ('SPECIAL TEAMS', 'power_plays_against', 'Short Handed', 'SHA', 'Short Handed Allowed', 8),
               ('SPECIAL TEAMS', 'goals_power_play_against', 'Short Handed', 'SHGA', 'Short Handed Goals Allowed', 9),
               ('SPECIAL TEAMS', 'goals-power-play-against-percentage', 'Short Handed', 'PCT', 'Short Handed Goals Allowed Percentage', 10),
               ('SPECIAL TEAMS', 'faceoff_total_wins', 'Faceoffs', 'FW', 'Faceoff Wins', 11),
               ('SPECIAL TEAMS', 'faceoff_total_losses', 'Faceoffs', 'FL', 'Faceoff Losses', 12),
               ('SPECIAL TEAMS', 'faceoff-total-wins-percentage', 'Faceoffs', 'FW%', 'Faceoff Win %', 13),               
               ('SPECIAL TEAMS', 'penalty_minutes', 'Penalties', 'PIM', 'Penalty Minutes', 14),
               ('SPECIAL TEAMS', 'penalty-minutes-per-game', 'Penalties', 'PIM/G', 'Penalty Minutes Per Game', 15)
              
        INSERT INTO @hockey (team_key, games_played, power_plays, goals_power_play, power_plays_against, goals_power_play_against,
                             faceoff_total_wins, faceoff_total_losses, penalty_minutes)
        SELECT p.team_key, ISNULL(games_played, 0),
               ISNULL(power_plays, 0), ISNULL(goals_power_play, 0), ISNULL(power_plays_against, 0), ISNULL(goals_power_play_against, 0),
               ISNULL(faceoff_total_wins, 0), ISNULL(faceoff_total_losses, 0), ISNULL(penalty_minutes, 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, power_plays, goals_power_play, power_plays_against, goals_power_play_against,
                                                faceoff_total_wins, faceoff_total_losses, penalty_minutes)) AS p

        -- calculations
        UPDATE @hockey
		   SET [goals-power-play-percentage] = REPLACE(CAST(CAST((CAST(goals_power_play AS FLOAT) / power_plays) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
		 WHERE power_plays > 0
		 
        UPDATE @hockey
		   SET [goals-power-play-against-percentage] = REPLACE(CAST(CAST((CAST(goals_power_play_against AS FLOAT) / power_plays_against) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
		 WHERE power_plays_against > 0

        UPDATE @hockey
		   SET [faceoff-total-wins-percentage] = REPLACE(CAST(CAST((CAST(faceoff_total_wins AS FLOAT) / (faceoff_total_wins + faceoff_total_losses)) AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
		 WHERE power_plays_against > 0

        UPDATE @hockey
           SET [penalty-minutes-per-game] = CAST(CAST((CAST([penalty_minutes] AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR)

        -- leaders                
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'POWER PLAY GOALS %', [goals-power-play-percentage] + ' PCT', 'SPECIAL TEAMS', 'goals-power-play-percentage'
          FROM @hockey
         ORDER BY CAST([goals-power-play-percentage] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'SHORT HANDED GOALS ALLOWED %', [goals-power-play-against-percentage] + ' PCT', 'SPECIAL TEAMS', 'goals-power-play-against-percentage'
          FROM @hockey
         ORDER BY CAST([goals-power-play-against-percentage] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'PENALTY MINUTES', CAST(penalty_minutes AS VARCHAR) + ' PIM', 'SPECIAL TEAMS', 'penalty_minutes'
          FROM @hockey
         ORDER BY penalty_minutes DESC         

        UPDATE l
           SET l.team_logo = dbo.SMG_fnTeamLogo('nhl', st.team_abbreviation, '80'),
               l.team_rgb = st.rgb, l.team_link = '/sports/nhl/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'POWER PLAY GOALS %', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'POWER PLAY GOALS %')
         ORDER BY CAST([goals-power-play-percentage] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'SHORT HANDED GOALS ALLOWED %', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'SHORT HANDED GOALS ALLOWED %')
         ORDER BY CAST([goals-power-play-against-percentage] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'PENALTY MINUTES', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'PENALTY MINUTES')
         ORDER BY penalty_minutes DESC

	    UPDATE l
	       SET l.name = st.team_last, l.abbr = st.team_abbreviation
	      FROM @leaders l
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

	    UPDATE t
	       SET t.name = st.team_last
	      FROM @teams t
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = t.team_key AND st.season_key = @seasonKey

	    UPDATE h
	       SET h.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = h.team_key AND st.season_key = @seasonKey
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('SPECIAL TEAMS', 'special', 'goals-power-play-percentage')


        SELECT
        (
            SELECT 'SPECIAL TEAMS LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, team_link,
                   team_key, name, abbr, ribbon, value, reference_ribbon, reference_column,
                   (
                       SELECT team_key, name
                        FROM @teams
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('team'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'SPECIAL TEAMS' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('special_column'), TYPE
        ),
        (
            SELECT team, games_played, power_plays, goals_power_play, [goals-power-play-percentage],
                   power_plays_against, goals_power_play_against, [goals-power-play-against-percentage],
                   faceoff_total_wins, faceoff_total_losses, [faceoff-total-wins-percentage], penalty_minutes, [penalty-minutes-per-game]
              FROM @hockey
             ORDER BY CAST([goals-power-play-percentage] AS FLOAT) DESC
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
        VALUES ('OFFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('OFFENSE', 'games_played', '', 'GP', 'Games Played', 3),
               ('OFFENSE', 'goals', 'Goals', 'RG', 'Regulation Goals', 4),
               ('OFFENSE', 'goals_overtime', 'Goals', 'OG', 'Overtime Goals', 5),
               ('OFFENSE', 'total-goals', 'Goals', 'G', 'Goals', 6),
               ('OFFENSE', 'total-goals-per-game', 'Goals', 'G/G', 'Goals Per Game', 7),
               ('OFFENSE', 'shots', 'Shots', 'RS', 'Regulation Shots', 8),
               ('OFFENSE', 'shots_overtime', 'Shots', 'OS', 'Overtime Shots', 9),
               ('OFFENSE', 'total-shots', 'Shots', 'S', 'Shots', 10),
               ('OFFENSE', 'total-shots-per-game', 'Shots', 'S/G', 'Shots Per Game', 11),
               ('OFFENSE', 'shutouts', '', 'SO', 'Shutouts', 12)
              
        INSERT INTO @hockey (team_key, games_played, goals, goals_overtime, shots, shots_overtime, shutouts)
        SELECT p.team_key, games_played, goals, goals_overtime, shots, shots_overtime, shutouts
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (games_played, goals, goals_overtime, shots, shots_overtime, shutouts)) AS p

        -- calculations
        UPDATE @hockey
           SET [total-goals] = (goals + goals_overtime),
               [total-shots] = (shots + shots_overtime)

        UPDATE @hockey
           SET [total-goals-per-game] = CAST(CAST((CAST([total-goals] AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR),
               [total-shots-per-game] = CAST(CAST((CAST([total-shots] AS FLOAT) / games_played) AS DECIMAL(4, 1)) AS VARCHAR)

        -- leaders
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'GOALS', CAST([goals] AS VARCHAR) + ' G', 'OFFENSE', 'goals'
          FROM @hockey
         ORDER BY goals DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'GOALS PER GAME', [total-goals-per-game] + ' G/G', 'OFFENSE', 'total-goals-per-game'
          FROM @hockey
         ORDER BY CAST([total-goals-per-game] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'SHOTS PER GAME', [total-shots-per-game] + ' S/G', 'OFFENSE', 'total-shots-per-game'
          FROM @hockey
         ORDER BY CAST([total-shots-per-game] AS FLOAT) DESC

        UPDATE l
           SET l.team_logo = dbo.SMG_fnTeamLogo('nhl', st.team_abbreviation, '80'),
               l.team_rgb = st.rgb, l.team_link = '/sports/nhl/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'GOALS', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'GOALS')
         ORDER BY goals DESC          

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'GOALS PER GAME', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'GOALS PER GAME')
         ORDER BY CAST([total-goals-per-game] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'SHOTS PER GAME', team_key
          FROM @hockey
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'SHOTS PER GAME')
         ORDER BY CAST([total-shots-per-game] AS FLOAT) DESC

	    UPDATE l
	       SET l.name = st.team_last, l.abbr = st.team_abbreviation
	      FROM @leaders l
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

	    UPDATE t
	       SET t.name = st.team_last
	      FROM @teams t
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = t.team_key AND st.season_key = @seasonKey

	    UPDATE h
	       SET h.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @hockey h
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = h.team_key AND st.season_key = @seasonKey
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('OFFENSE', 'offense', 'goals')


        SELECT
        (
            SELECT 'OFFENSIVE LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, team_link,
                   team_key, name, abbr, ribbon, value, reference_ribbon, reference_column,
                   (
                       SELECT team_key, name
                        FROM @teams
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('team'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'asc,desc' AS [sort],
                   CASE
                       WHEN [column] IN ('team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('offense_column'), TYPE
        ),
        (
            SELECT team, games_played, goals, goals_overtime, [total-goals], [total-goals-per-game],
                   shots, shots_overtime, [total-shots], [total-shots-per-game], shutouts
              FROM @hockey
             ORDER BY goals DESC
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
