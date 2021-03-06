USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAStatistics_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAStatistics_football_XML]
    @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/07/2014
  -- Description: get statistics for ncaa football team
  -- Update:      11/19/2014 - John Lin - men -> mens
  --              02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'ncaaf' AND page = 'statistics'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND team_slug = @teamSlug


    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    DECLARE @super_columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAr(100),
        column_display VARCHAR(100),
        column_span INT    
    )
    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        player_key VARCHAR(100),
        table_name VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        player_key  VARCHAR(100),
        column_name VARCHAR(100), 
        value       VARCHAR(100)
    )
    INSERT INTO @tables (table_name, table_display)
    VALUES ('passing', 'passing offense'), ('rushing', 'rushing offense'),
           ('receiving', 'receiving offense'), ('scoring', 'total scoring (touchdowns)'),
           ('kicking', 'kicking (field goals)'), ('punting', 'punting'),
           ('returning', 'returning')

    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('passing', 'player_display', 'NAME'),
           ('passing', 'passes_completions', 'COMP'),
           ('passing', 'passes_attempts', 'ATT'),
           ('passing', 'passes_percentage', 'PCT'),
           ('passing', 'passer_rating', 'RAT'),
           ('passing', 'passes_yards_gross', 'YDS'),
           ('passing', 'passes_average_yards_per', 'YDS/A'),
           ('passing', 'passes_yards_gross_per_game', 'YDS/G'),
           ('passing', 'passes_longest', 'LNG'),
           ('passing', 'passes_touchdowns', 'TD'),
           ('passing', 'passes_interceptions', 'INT'),
           ('passing', 'sacks_against_total', 'SACK'),
           
           ('rushing', 'player_display', 'NAME'),
           ('rushing', 'rushes_attempts', 'ATT'),
           ('rushing', 'rushes_yards', 'YDS'),
           ('rushing', 'rushing_average_yards_per', 'YDS/A'),
           ('rushing', 'rushes_longest', 'LNG'),
           ('rushing', 'rushes_yards_per_game', 'YDS/G'),
           ('rushing', 'rushes_touchdowns', 'TD'),
           ('rushing', 'fumbles_committed', 'FUM'),
           
           ('receiving', 'player_display', 'NAME'),
           ('receiving', 'receptions_total', 'REC'),
           ('receiving', 'receptions_yards', 'YDS'),
           ('receiving', 'receptions_average_yards_per', 'AVG'),
           ('receiving', 'receptions_longest', 'LNG'),
           ('receiving', 'receptions_yards_per_game', 'YDS/G'),
           ('receiving', 'receptions_touchdowns', 'TD'),
           
           ('scoring', 'player_display', 'NAME'),
           ('scoring', 'rushes_touchdowns', 'RUSH'),
           ('scoring', 'receptions_touchdowns', 'REC'),
           ('scoring', 'interceptions_touchdown', 'INT'),
           ('scoring', 'fumbles_opposing_touchdowns', 'FUM'),
           ('scoring', 'returns_kickoff_touchdown', 'KRET'),
           ('scoring', 'returns_punt_touchdown', 'PRET'),
           ('scoring', 'touchdowns_total', 'TOTAL'),
           
           ('kicking', 'player_display', 'NAME'),
           ('kicking', 'field_goals_made', 'FGM'),
           ('kicking', 'field_goal_attempts', 'FGA'),
           ('kicking', 'field_goals_percentage', 'PCT'),

           ('punting', 'player_display', 'NAME'),
           ('punting', 'punts_total', 'PUNTS'),
           ('punting', 'punts_yards_gross', 'YDS'),
           ('punting', 'punts_average', 'AVG'),
           ('punting', 'punts_inside_20', 'IN20'),

           ('returning', 'player_display', 'NAME'),
           ('returning', 'returns_kickoff_total', 'ATT'),
           ('returning', 'returns_kickoff_yards', 'YDS'),
           ('returning', 'returns_kickoff_average', 'AVG'),
           ('returning', 'returns_kickoff_longest', 'LNG'),
           ('returning', 'returns_kickoff_touchdown', 'TD'),
           ('returning', 'returns_punt_total', 'ATT'),
           ('returning', 'returns_punt_yards', 'YDS'),
           ('returning', 'returns_punt_average', 'AVG'),
           ('returning', 'returns_punt_longest', 'LNG'),
           ('returning', 'returns_punt_touchdown', 'TD')


    INSERT INTO @super_columns (table_name, column_display, column_span)
    VALUES ('returning', '', 1),
           ('returning', '', 1),
           ('returning', 'kickoffs', 5),
           ('returning', 'punts', 5)


    -- passing
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'passing'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'passes-attempts' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'passing' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('passes-completions', 'passes-attempts', 'passes-percentage', 'passer-rating', 'passes-yards-gross', 'passes-average-yards-per',
                             'passes-yards-gross-per-game', 'passes-longest', 'passes-touchdowns', 'passes-interceptions', 'sacks-against-total')

    -- rushing
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'rushing'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'rushes-attempts' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'rushing' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('rushes-attempts', 'rushes-yards', 'rushing-average-yards-per', 'rushes-longest', 'rushes-yards-per-game', 'rushes-touchdowns', 'fumbles-committed')

    -- receiving
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'receiving'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'receptions-total' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'receiving' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('receptions-total', 'receptions-yards', 'receptions-average-yards-per', 'receptions-longest', 'receptions-yards-per-game', 'receptions-touchdowns')

    -- scoring
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'scoring'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND team_key = @team_key AND
           [column] IN ('rushes-touchdowns', 'receptions-touchdowns', 'interceptions-touchdown', 'fumbles-opposing-touchdowns',
                        'returns-kickoff-touchdown', 'returns-punt-touchdown') AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'scoring' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('rushes-touchdowns', 'receptions-touchdowns', 'interceptions-touchdown', 'fumbles-opposing-touchdowns',
                             'returns-kickoff-touchdown', 'returns-punt-touchdown')

    -- kicking
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'kicking'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'field-goal-attempts' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'kicking' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('field-goals-made', 'field-goal-attempts', 'field-goals-percentage')

    -- punting
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'punting'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'punts-total' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'punting' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('punts-total', 'punts-yards-gross', 'punts-average', 'punts-inside-20')

    -- returning
    INSERT INTO @players (player_key, table_name)
    SELECT player_key, 'returning'
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] IN ('returns-kickoff-total', 'returns-punt-total') AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key AND p.table_name = 'returning' AND spss.player_key <> 'team'
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('returns-kickoff-total', 'returns-kickoff-yards', 'returns-kickoff-average', 'returns-kickoff-longest', 'returns-kickoff-touchdown',
                             'returns-punt-total', 'returns-punt-yards', 'returns-punt-average', 'returns-punt-longest', 'returns-punt-touchdown')


    DECLARE @football TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        -- passing
        passes_completions INT,
        passes_attempts INT,
        passes_percentage VARCHAR(100),
        passer_rating VARCHAR(100),
        passes_yards_gross INT,
        passes_average_yards_per VARCHAR(100),
        passes_yards_gross_per_game VARCHAR(100),
        passes_longest INT,
        passes_touchdowns INT,
        passes_interceptions INT,
        sacks_against_total INT,
        -- rushing
        rushes_attempts INT,
        rushes_yards INT,
        rushing_average_yards_per VARCHAR(100),
        rushes_longest INT,
        rushes_yards_per_game VARCHAR(100),
        rushes_touchdowns INT,
        fumbles_committed INT,
        -- receiving
        receptions_total INT,
        receptions_yards INT,
        receptions_average_yards_per VARCHAR(100),
        receptions_longest INT,
        receptions_yards_per_game VARCHAR(100),
        receptions_touchdowns INT,
        -- kicking
        field_goals_made INT,
        field_goal_attempts INT,
        field_goals_percentage VARCHAR(100),
        -- punting
        punts_total INT,
        punts_yards_gross INT,
        punts_average VARCHAR(100),
        punts_inside_20 INT,
        -- returning
        returns_kickoff_total INT,
        returns_kickoff_yards INT,
        returns_kickoff_average VARCHAR(100),
        returns_kickoff_longest INT,
        returns_kickoff_touchdown INT,
        returns_punt_total INT,
        returns_punt_yards INT,
        returns_punt_average VARCHAR(100),
        returns_punt_longest INT,
        returns_punt_touchdown INT,
        -- scoring
        interceptions_touchdown INT,
        fumbles_opposing_touchdowns INT,
        touchdowns_total INT
    )

    INSERT INTO @football (player_key,
                           passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross, passes_average_yards_per,
                           passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total,
                           rushes_attempts, rushes_yards, rushing_average_yards_per, rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed,                         
                           receptions_total, receptions_yards, receptions_average_yards_per, receptions_longest, receptions_yards_per_game, receptions_touchdowns,
                           field_goals_made, field_goal_attempts, field_goals_percentage,
                           punts_total, punts_yards_gross, punts_average, punts_inside_20,
                           returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest, returns_kickoff_touchdown,
                           returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown,
                           interceptions_touchdown, fumbles_opposing_touchdowns)
    SELECT p.player_key,
           passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross, passes_average_yards_per,
           passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total,
           rushes_attempts, rushes_yards, rushing_average_yards_per, rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed,
           receptions_total, receptions_yards, receptions_average_yards_per, receptions_longest, receptions_yards_per_game, receptions_touchdowns,
           field_goals_made, field_goal_attempts, field_goals_percentage,
           punts_total, punts_yards_gross, punts_average, punts_inside_20,
           returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest, returns_kickoff_touchdown,
           returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown,
           interceptions_touchdown, fumbles_opposing_touchdowns
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross, passes_average_yards_per,
                                               passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total,
                                               rushes_attempts, rushes_yards, rushing_average_yards_per, rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed,
                                               receptions_total, receptions_yards, receptions_average_yards_per, receptions_longest, receptions_yards_per_game, receptions_touchdowns,
                                               field_goals_made, field_goal_attempts, field_goals_percentage,
                                               punts_total, punts_yards_gross, punts_average, punts_inside_20,
                                               returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest, returns_kickoff_touchdown,
                                               returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown,
                                               interceptions_touchdown, fumbles_opposing_touchdowns)) AS p


     -- position_regular, name
     UPDATE f
        SET f.player_display = sp.first_name + ' ' + sp.last_name + ', ' + sr.position_regular
       FROM @football f
      INNER JOIN dbo.SMG_Players sp
         ON sp.player_key = f.player_key
      INNER JOIN dbo.SMG_Rosters sr
         ON sr.season_key = @season_key AND sr.team_key = @team_key AND sr.player_key = f.player_key


    -- passing
    DECLARE @passing TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        passes_completions INT,
        passes_attempts INT,
        passes_percentage VARCHAR(100),
        passer_rating VARCHAR(100),
        passes_yards_gross INT,
        passes_average_yards_per VARCHAR(100),
        passes_yards_gross_per_game VARCHAR(100),
        passes_longest INT,
        passes_touchdowns INT,
        passes_interceptions INT,
        sacks_against_total INT
    )
	INSERT INTO @passing (player_key, player_display, passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross,
	                      passes_average_yards_per, passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total)
	SELECT player_key, player_display, passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross,
	       passes_average_yards_per, passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total
	  FROM @football
     WHERE passes_attempts IS NOT NULL AND passes_attempts <> '' AND passes_attempts > 0

    -- rushing
    DECLARE @rushing TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        rushes_attempts INT,
        rushes_yards INT,
        rushing_average_yards_per VARCHAR(100),
        rushes_longest INT,
        rushes_yards_per_game VARCHAR(100),
        rushes_touchdowns INT,
        fumbles_committed INT
    )
	INSERT INTO @rushing (player_key, player_display, rushes_attempts, rushes_yards, rushing_average_yards_per,
	                      rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed)
	SELECT player_key, player_display, rushes_attempts, rushes_yards, rushing_average_yards_per,
	       rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed
	  FROM @football
     WHERE rushes_attempts IS NOT NULL AND rushes_attempts <> '' AND rushes_attempts > 0

    -- receiving
    DECLARE @receiving TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        receptions_total INT,
        receptions_yards INT,
        receptions_average_yards_per VARCHAR(100),
        receptions_longest INT,
        receptions_yards_per_game VARCHAR(100),
        receptions_touchdowns INT
    )
	INSERT INTO @receiving (player_key, player_display, receptions_total, receptions_yards, receptions_average_yards_per,
	                        receptions_longest, receptions_yards_per_game, receptions_touchdowns)
	SELECT player_key, player_display, receptions_total, receptions_yards, receptions_average_yards_per,
	       receptions_longest, receptions_yards_per_game, receptions_touchdowns
	  FROM @football
     WHERE receptions_total IS NOT NULL AND receptions_total <> '' AND receptions_total > 0

    -- scoring
    DECLARE @scoring TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        rushes_touchdowns INT,
        receptions_touchdowns INT,
        interceptions_touchdown INT,
        fumbles_opposing_touchdowns INT,
        returns_kickoff_touchdown INT,
        returns_punt_touchdown INT,
        touchdowns_total INT
    )
	INSERT INTO @scoring (player_display, rushes_touchdowns, receptions_touchdowns, interceptions_touchdown,
	                      fumbles_opposing_touchdowns, returns_kickoff_touchdown, returns_punt_touchdown)
	SELECT player_display, rushes_touchdowns, receptions_touchdowns, interceptions_touchdown,
	       fumbles_opposing_touchdowns, returns_kickoff_touchdown, returns_punt_touchdown
	  FROM @football
     WHERE (rushes_touchdowns IS NOT NULL AND rushes_touchdowns <> '' AND rushes_touchdowns > 0) OR
           (receptions_touchdowns IS NOT NULL AND receptions_touchdowns <> '' AND receptions_touchdowns > 0) OR
           (interceptions_touchdown IS NOT NULL AND interceptions_touchdown <> '' AND interceptions_touchdown > 0) OR
           (fumbles_opposing_touchdowns IS NOT NULL AND fumbles_opposing_touchdowns <> '' AND fumbles_opposing_touchdowns > 0) OR
           (returns_kickoff_touchdown IS NOT NULL AND returns_kickoff_touchdown <> '' AND returns_kickoff_touchdown > 0) OR
           (returns_punt_touchdown IS NOT NULL AND returns_punt_touchdown <> '' AND returns_punt_touchdown > 0)

    UPDATE @scoring
       SET touchdowns_total = rushes_touchdowns + receptions_touchdowns + interceptions_touchdown +
                              fumbles_opposing_touchdowns + returns_kickoff_touchdown + returns_punt_touchdown

    -- kicking
    DECLARE @kicking TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        field_goals_made INT,
        field_goal_attempts INT,
        field_goals_percentage VARCHAR(100)
    )
	INSERT INTO @kicking (player_key, player_display, field_goals_made, field_goal_attempts, field_goals_percentage)
	SELECT player_key, player_display, field_goals_made, field_goal_attempts, field_goals_percentage
	  FROM @football
     WHERE field_goal_attempts IS NOT NULL AND field_goal_attempts <> ''

    -- punting
    DECLARE @punting TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        punts_total INT,
        punts_yards_gross INT,
        punts_average VARCHAR(100),
        punts_inside_20 INT
    )
	INSERT INTO @punting (player_key, player_display, punts_total, punts_yards_gross, punts_average, punts_inside_20)
	SELECT player_key, player_display, punts_total, punts_yards_gross, punts_average, punts_inside_20
	  FROM @football
     WHERE punts_total IS NOT NULL AND punts_total <> ''

    -- returning
    DECLARE @returning TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        returns_kickoff_total INT,
        returns_kickoff_yards INT,
        returns_kickoff_average VARCHAR(100),
        returns_kickoff_longest INT,
        returns_kickoff_touchdown INT,
        returns_punt_total INT,
        returns_punt_yards INT,
        returns_punt_average VARCHAR(100),
        returns_punt_longest INT,
        returns_punt_touchdown INT
    )
	INSERT INTO @returning (player_key, player_display, returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest,
	                        returns_kickoff_touchdown, returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown)
	SELECT player_key, player_display, returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest,
	       returns_kickoff_touchdown, returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown
	  FROM @football
     WHERE (returns_kickoff_total IS NOT NULL AND returns_kickoff_total <> '') OR
           (returns_punt_total IS NOT NULL AND returns_punt_total <> '')



	SELECT
	(
		SELECT t.table_name, t.table_display,
		       (
				   SELECT c.column_name, c.column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
		       (
				   SELECT sc.column_display, sc.column_span
					 FROM @super_columns sc
					WHERE sc.table_name = t.table_name
					ORDER BY sc.id ASC
					  FOR XML PATH('super_columns'), TYPE
			   ),
               (
                   SELECT player_key, player_display, passes_completions, passes_attempts, passes_percentage, passer_rating, passes_yards_gross,
	                      passes_average_yards_per, passes_yards_gross_per_game, passes_longest, passes_touchdowns, passes_interceptions, sacks_against_total
                     FROM @passing
                    WHERE t.table_name = 'passing'
                    ORDER BY passes_yards_gross DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, rushes_attempts, rushes_yards, rushing_average_yards_per,
	                      rushes_longest, rushes_yards_per_game, rushes_touchdowns, fumbles_committed
                     FROM @rushing
                    WHERE t.table_name = 'rushing'
                    ORDER BY rushes_yards DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, receptions_total, receptions_yards, receptions_average_yards_per,
	                      receptions_longest, receptions_yards_per_game, receptions_touchdowns
                     FROM @receiving
                    WHERE t.table_name = 'receiving'
                    ORDER BY receptions_yards DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, rushes_touchdowns, receptions_touchdowns, interceptions_touchdown, fumbles_opposing_touchdowns,
                          returns_kickoff_touchdown, returns_punt_touchdown, touchdowns_total
                     FROM @scoring
                    WHERE t.table_name = 'scoring'
                    ORDER BY touchdowns_total DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, field_goals_made, field_goal_attempts, field_goals_percentage
                     FROM @kicking
                    WHERE t.table_name = 'kicking'
                    ORDER BY field_goal_attempts DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, punts_total, punts_yards_gross, punts_average, punts_inside_20
                     FROM @punting
                    WHERE t.table_name = 'punting'
                    ORDER BY punts_yards_gross DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, returns_kickoff_total, returns_kickoff_yards, returns_kickoff_average, returns_kickoff_longest,
                          returns_kickoff_touchdown, returns_punt_total, returns_punt_yards, returns_punt_average, returns_punt_longest, returns_punt_touchdown
                     FROM @returning
                    WHERE t.table_name = 'returning'
                    ORDER BY returns_kickoff_yards DESC, returns_punt_yards DESC
                      FOR XML PATH('rows'), TYPE
               )
   		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('statistics'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END

GO
