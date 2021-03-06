USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Statistics_basketball_team_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Statistics_basketball_team_XML]
   @leagueName    VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/02/2013
  -- Description: get basketball league team statistics
  -- Update: 10/21/2013 - John Lin - use team slug
  --         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
  --         06/05/2015 - ikenticus - replacing hard-coded league_key with function for non-xmlteam results
  --         07/22/2015 - John Lin - STATS migration
  --         09/09/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

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
         WHERE league_key = @league_key AND conference_display = @affiliation
         
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
    DECLARE @basketball TABLE
    (
        team_key VARCHAR(100),
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
        [three-point-field-goals-percentage] VARCHAR(100),
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
              
        INSERT INTO @basketball (team_key, games_played, steals_against, blocks_against, fouls_personal_against, fouls_technical_against,
                                 rebounds_team_against, rebounds_defensive_against, rebounds_offensive_against)                 
        SELECT p.team_key, ISNULL(games_played, 0), ISNULL(steals_against, 0), ISNULL(blocks_against, 0),
               ISNULL(fouls_personal_against, 0), ISNULL(fouls_technical_against, 0),
               ISNULL(rebounds_team_against, 0), ISNULL(rebounds_defensive_against, 0), ISNULL(rebounds_offensive_against, 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
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
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'REBOUNDS', [rebounds-team-against-per-game] + ' R/G', 'DEFENSE', 'rebounds-team-against-per-game'
          FROM @basketball
         ORDER BY CAST([rebounds-team-against-per-game] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'BLOCKS', [blocks-against-per-game] + ' B/G', 'DEFENSE', 'blocks-against-per-game'
          FROM @basketball
         ORDER BY CAST([blocks-against-per-game] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'STEALS', [steals-against-per-game] + ' STL/G', 'DEFENSE', 'steals-against-per-game'
          FROM @basketball
         ORDER BY CAST([steals-against-per-game] AS FLOAT) DESC

        UPDATE l
           SET l.team_logo = dbo.SMG_fnTeamLogo(@leagueName, st.team_abbreviation, '80'),
               l.team_rgb = st.rgb, l.team_link = '/sports/' + @leagueName + '/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'REBOUNDS', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'REBOUNDS')
         ORDER BY CAST([rebounds-team-against-per-game] AS FLOAT) DESC          

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'BLOCKS', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'BLOCKS')
         ORDER BY CAST([blocks-against-per-game] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'STEALS', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'STEALS')
         ORDER BY CAST([steals-against-per-game] AS FLOAT) DESC

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

	    UPDATE b
	       SET b.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = b.team_key AND st.season_key = @seasonKey
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('DEFENSE', 'defense', 'rebounds-team-against-per-game')



        SELECT
        (
            SELECT 'DEFENSE LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb,
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
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('fouls_personal_against', 'fouls_technical_against') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
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
            SELECT team, games_played, [rebounds-offensive-against-per-game], [rebounds-defensive-against-per-game], [rebounds-team-against-per-game],
                   rebounds_team_against, [steals-against-per-game], steals_against, [blocks-against-per-game], blocks_against, fouls_personal_against,
                   fouls_technical_against
              FROM @basketball
             ORDER BY CAST([rebounds-team-against-per-game] AS FLOAT) ASC
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
        VALUES ('OFFENSE', 'team', '', 'TEAM', 'Team', 2),
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
              
        INSERT INTO @basketball (team_key, games_played, points, assists, turnovers,
                                 field_goals_made, field_goals_attempted, free_throws_made, free_throws_attempted,
                                 three_point_field_goals_made, three_point_field_goals_attempted)
        SELECT p.team_key, ISNULL(games_played, 0), ISNULL(points, 0), ISNULL(assists, 0), ISNULL(turnovers, 0),
               ISNULL(field_goals_made, 0), ISNULL(field_goals_attempted, 0), ISNULL(free_throws_made, 0), ISNULL(free_throws_attempted, 0),
               ISNULL(three_point_field_goals_made, 0), ISNULL(three_point_field_goals_attempted, 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
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
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'POINTS', CAST(points AS VARCHAR) + ' PTS', 'OFFENSE', 'points'
          FROM @basketball
         ORDER BY points DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'ASSISTS', CAST(assists AS VARCHAR) + ' AST', 'OFFENSE', 'assists'
          FROM @basketball
         ORDER BY assists DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'FIELD GOAL PERCENTAGE', [field-goals-percentage] + ' FG%', 'OFFENSE', 'field-goals-percentage'
          FROM @basketball
         ORDER BY CAST([field-goals-percentage] AS FLOAT) DESC         

        UPDATE l
           SET l.team_logo = dbo.SMG_fnTeamLogo(@leagueName, st.team_abbreviation, '80'),
               l.team_rgb = st.rgb, l.team_link = '/sports/' + @leagueName + '/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'POINTS', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'POINTS')
         ORDER BY points DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'ASSISTS', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'ASSISTS')
         ORDER BY assists DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'FIELD GOAL PERCENTAGE', team_key
          FROM @basketball
         WHERE team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'FIELD GOAL PERCENTAGE')
         ORDER BY CAST([field-goals-percentage] AS FLOAT) DESC

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

	    UPDATE b
	       SET b.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @basketball b
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = b.team_key AND st.season_key = @seasonKey
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('OFFENSE', 'offense', 'points')



        SELECT
        (
            SELECT 'OFFENSE LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, 
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
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('turnovers', 'turnovers-per-game') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
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
            SELECT team, games_played, points, [points-per-game], field_goals_made, field_goals_attempted, [field-goals-percentage],
                   three_point_field_goals_made, three_point_field_goals_attempted, [three-point-field-goals-percentage],
                   free_throws_made, free_throws_attempted, [free-throws-percentage], assists, [assists-per-game], turnovers, [turnovers-per-game]
              FROM @basketball
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
