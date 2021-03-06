USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAStatistics_basketball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAStatistics_basketball_XML]
    @teamSlug VARCHAR(100),
    @sport VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 11/20/2014
  -- Description: get statistics for ncaa basketball team
  --              02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         	  03/02/2015 - pkamat - change column rebounds-total-per-game to rebounds-per-game
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = 'l.ncaa.org.mbasket'
    DECLARE @league_name VARCHAR(100) = 'ncaab'
    DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)
   
    IF (@sport = 'womens-basketball')
    BEGIN
        SET @league_key = 'l.ncaa.org.wbasket'
        SET @league_name = 'ncaaw'        
    END

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @league_name AND page = 'statistics'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
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
        player_key VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        player_key  VARCHAR(100),
        column_name VARCHAR(100), 
        value       VARCHAR(100)
    )
    INSERT INTO @tables (table_name, table_display)
    VALUES ('season', 'Season'), ('per_game', 'Per Game')

    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('season', 'player_display', 'NAME'),
           ('season', 'events_played', 'G'),
           ('season', 'field_goals_made', 'FGM'),
           ('season', 'field_goals_attempted', 'FGA'),
           ('season', 'field_goals_percentage', 'FG%'),
           ('season', 'three_pointers_made', '3PM'),
           ('season', 'three_pointers_attempted', '3PA'),
           ('season', 'three_pointers_percentage', '3P%'),
           ('season', 'free_throws_made', 'FTM'),
           ('season', 'free_throws_attempted', 'FTA'),
           ('season', 'free_throws_percentage', 'FT%'),
           ('season', 'rebounds_total', 'REB'),
           ('season', 'assists_total', 'AST'),
           ('season', 'steals_total', 'STL'),
           ('season', 'blocks_total', 'BLK'),
           ('season', 'turnovers_total', 'TO'),
           ('season', 'points_scored_for', 'PTS'),

           ('per_game', 'player_display', 'NAME'),
           ('per_game', 'field_goals_made_per_game', 'FGM'),
           ('per_game', 'field_goals_attempted_per_game', 'FGA'),
           ('per_game', 'field_goals_percentage_per_game', 'FG%'),
           ('per_game', 'three_pointers_made_per_game', '3PM'),
           ('per_game', 'three_pointers_attempted_per_game', '3PA'),
           ('per_game', 'three_pointers_percentage_per_game', '3P%'),
           ('per_game', 'free_throws_made_per_game', 'FTM'),
           ('per_game', 'free_throws_attempted_per_game', 'FTA'),
           ('per_game', 'free_throws_percentage_per_game', 'FT%'),
           ('per_game', 'rebounds_total_per_game', 'REB'),
           ('per_game', 'assists_total_per_game', 'AST'),
           ('per_game', 'steals_total_per_game', 'STL'),
           ('per_game', 'blocks_total_per_game', 'BLK'),
           ('per_game', 'turnovers_total_per_game', 'TO'),
           ('per_game', 'points_scored_for_per_game', 'PTS')

    INSERT INTO @players (player_key)
    SELECT player_key
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular' AND
           team_key = @team_key AND [column] = 'events-played' AND value <> '0' AND player_key <> 'team'

    INSERT INTO @stats (player_key, column_name, value)
    SELECT spss.player_key, REPLACE(spss.[column], '-', '_'), spss.value 
      FROM SportsEditDB.dbo.SMG_Statistics spss
     INNER JOIN @players p
        ON p.player_key = spss.player_key
     WHERE spss.season_key = @season_key AND spss.sub_season_type = 'season-regular' AND spss.team_key = @team_key AND
           spss.[column] IN ('events-played', 'field-goals-made', 'field-goals-attempted', 'field-goals-percentage', 'three-pointers-made',
                             'three-pointers-attempted', 'three-pointers-percentage', 'free-throws-made', 'free-throws-attempted',
                             'free-throws-percentage', 'rebounds-total', 'assists-total', 'steals-total', 'blocks-total', 'turnovers-total',
                             'points-scored-for',
                             'field-goals-made-per-game', 'field-goals-attempted-per-game', 'field-goals-percentage-per-game',
                             'three-pointers-made-per-game', 'three-pointers-attempted-per-game', 'three-pointers-percentage-per-game',
                             'free-throws-made-per-game', 'free-throws-attempted-per-game', 'free-throws-percentage-per-game',
                             'rebounds-per-game', 'assists-total-per-game', 'steals-total-per-game', 'blocks-total-per-game',
                             'turnovers-total-per-game', 'points-scored-for-per-game')


    DECLARE @basketball TABLE
    (
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        -- season
        events_played INT,
        field_goals_made INT,
        field_goals_attempted INT,
        field_goals_percentage VARCHAR(100),
        three_pointers_made INT,
        three_pointers_attempted INT,
        three_pointers_percentage VARCHAR(100),
        free_throws_made INT,
        free_throws_attempted INT,
        free_throws_percentage VARCHAR(100),
        rebounds_total INT,
        assists_total INT,
        steals_total INT,
        blocks_total INT,
        turnovers_total INT,
        points_scored_for INT,
        -- per game
        field_goals_made_per_game VARCHAR(100),
        field_goals_attempted_per_game VARCHAR(100),
        field_goals_percentage_per_game VARCHAR(100),
        three_pointers_made_per_game VARCHAR(100),
        three_pointers_attempted_per_game VARCHAR(100),
        three_pointers_percentage_per_game VARCHAR(100),
        free_throws_made_per_game VARCHAR(100),
        free_throws_attempted_per_game VARCHAR(100),
        free_throws_percentage_per_game VARCHAR(100),
        rebounds_total_per_game VARCHAR(100),
        assists_total_per_game VARCHAR(100),
        steals_total_per_game VARCHAR(100),
        blocks_total_per_game VARCHAR(100),
        turnovers_total_per_game VARCHAR(100),
        points_scored_for_per_game VARCHAR(100)
    )

    INSERT INTO @basketball (player_key,
                             events_played, field_goals_made, field_goals_attempted, field_goals_percentage, three_pointers_made,
                             three_pointers_attempted, three_pointers_percentage, free_throws_made, free_throws_attempted,
                             free_throws_percentage, rebounds_total, assists_total, steals_total, blocks_total, turnovers_total,
                             points_scored_for,
                             field_goals_made_per_game, field_goals_attempted_per_game, field_goals_percentage_per_game,
                             three_pointers_made_per_game, three_pointers_attempted_per_game, three_pointers_percentage_per_game,
                             free_throws_made_per_game, free_throws_attempted_per_game, free_throws_percentage_per_game,
                             rebounds_total_per_game, assists_total_per_game, steals_total_per_game, blocks_total_per_game,
                             turnovers_total_per_game, points_scored_for_per_game)
    SELECT p.player_key,
           events_played, field_goals_made, field_goals_attempted, field_goals_percentage, three_pointers_made, three_pointers_attempted,
           three_pointers_percentage, free_throws_made, free_throws_attempted, free_throws_percentage, rebounds_total, assists_total,
           steals_total, blocks_total, turnovers_total, points_scored_for,
           field_goals_made_per_game, field_goals_attempted_per_game, field_goals_percentage_per_game, three_pointers_made_per_game,
           three_pointers_attempted_per_game, three_pointers_percentage_per_game, free_throws_made_per_game, free_throws_attempted_per_game,
           free_throws_percentage_per_game, rebounds_total_per_game, assists_total_per_game, steals_total_per_game, blocks_total_per_game,
           turnovers_total_per_game, points_scored_for_per_game
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (events_played, field_goals_made, field_goals_attempted, field_goals_percentage, three_pointers_made,
                                               three_pointers_attempted, three_pointers_percentage, free_throws_made, free_throws_attempted,
                                               free_throws_percentage, rebounds_total, assists_total, steals_total, blocks_total, turnovers_total,
                                               points_scored_for,
                                               field_goals_made_per_game, field_goals_attempted_per_game, field_goals_percentage_per_game,
                                               three_pointers_made_per_game, three_pointers_attempted_per_game, three_pointers_percentage_per_game,
                                               free_throws_made_per_game, free_throws_attempted_per_game, free_throws_percentage_per_game,
                                               rebounds_total_per_game, assists_total_per_game, steals_total_per_game, blocks_total_per_game,
                                               turnovers_total_per_game, points_scored_for_per_game)) AS p


     -- position_regular, name
     UPDATE b
        SET b.player_display = sp.first_name + ' ' + sp.last_name + ', ' + sr.position_regular
       FROM @basketball b
      INNER JOIN dbo.SMG_Players sp
         ON sp.player_key = b.player_key
      INNER JOIN dbo.SMG_Rosters sr
         ON sr.season_key = @season_key AND sr.team_key = @team_key AND sr.player_key = b.player_key



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
                   SELECT player_key, player_display, events_played, field_goals_made, field_goals_attempted, field_goals_percentage,
                          three_pointers_made, three_pointers_attempted, three_pointers_percentage, free_throws_made, free_throws_attempted,
                          free_throws_percentage, rebounds_total, assists_total, steals_total, blocks_total, turnovers_total, points_scored_for
                     FROM @basketball
                    WHERE t.table_name = 'season'
                    ORDER BY points_scored_for DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_key, player_display, field_goals_made_per_game, field_goals_attempted_per_game, field_goals_percentage_per_game,
                          three_pointers_made_per_game, three_pointers_attempted_per_game, three_pointers_percentage_per_game,
                          free_throws_made_per_game, free_throws_attempted_per_game, free_throws_percentage_per_game, rebounds_total_per_game,
                          assists_total_per_game, steals_total_per_game, blocks_total_per_game, turnovers_total_per_game, points_scored_for_per_game
                     FROM @basketball
                    WHERE t.table_name = 'per_game'
                    ORDER BY CAST(points_scored_for_per_game AS FLOAT) DESC
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
