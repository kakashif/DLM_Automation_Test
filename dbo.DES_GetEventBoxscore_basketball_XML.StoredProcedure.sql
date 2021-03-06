USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_basketball_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_basketball_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/24/2014
-- Description:	get boxscore for desktop for basketball
-- Update:		02/24/2014 - ikenticus: rendering basketball as key-value instead of ordered value-list
--              03/06/2014 - ikenticus: adding footer (under total) for basketball, order by status (default to unknown)
--              03/13/2014 - John Lin - check if div by zero
--              05/01/2014 - thlam - add head to head comparison
--              05/09/2014 - John Lin - use stats for head to head
--              05/16/2014 - John Lin - use SMG_PERIODS
--              05/23/2014 - John Lin - head to head for pro basketball only
--              06/11/2014 - thlam - show head to head and mintues if post-event
--         		06/05/2015 - ikenticus - using non-xmlteam league_key logic
-- 				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--              09/18/2015 - John Lin - SDI migration
--				10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)
    DECLARE @officials VARCHAR(MAX)
    
    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
           @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
			   @away_team_key = away_team_key, @home_team_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    DECLARE @linescore TABLE
    (
        period       INT,
        period_value VARCHAR(100),
        away_value   VARCHAR(100),
        home_value   VARCHAR(100)
    )
    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key

    SELECT @officials = value
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND column_type = 'officials'
      
    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    INSERT INTO @tables (table_name, table_display)
    VALUES ('default', '')

    DECLARE @footer TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_span	   INT
    )
    INSERT INTO @footer (table_name, column_name, column_span)
    VALUES ('default', 'footer_display', 2), ('default', 'field-goals-percentage', 1),
           ('default', 'three-point-field-goals-percentage', 1), ('default', 'free-throws-percentage', 1)

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100),
        tooltip        VARCHAR(100)
    )
    INSERT INTO @columns (table_name, column_name, column_display, tooltip)
    VALUES ('default', 'player_display', 'PLAYER', 'Player'),
           ('default', 'minutes-played', 'MIN', 'Minutes'),
           ('default', 'field-goals-made-attempted', 'FGM-A', 'Field Goals Made - Attempted'),
           ('default', 'three-point-field-goals-made-attempted', '3PM-A', '3 Points Made - Attempted'),
           ('default', 'free-throws-made-attempted', 'FTM-A', 'Free Thows Made - Attempted'),
           ('default', 'rebounds_offensive', 'OR', 'Offensive Rebounds'), 
           ('default', 'rebounds_defensive', 'DR', 'Defensive Rebounds'),
           ('default', 'rebounds-total', 'REB', 'Total Rebounds'),
           ('default', 'assists', 'AST', 'Assists'),
           ('default', 'fouls_personal', 'PF', 'Personal Fouls'),
           ('default', 'steals', 'STL', 'Steals'),
           ('default', 'turnovers', 'TO', 'Turnovers'), 
	       ('default', 'blocks', 'BLK', 'Blocks'),
		   ('default', 'points', 'PTS', 'Points')

    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_basketball
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND event_key = @event_key

    DECLARE @basketball TABLE
	(
		team_key         VARCHAR(100),
		player_key       VARCHAR(100),
	    player_display   VARCHAR(100),
	    [position-event] VARCHAR(100),
	    games_started    INT,
	    seconds_played   INT,
	    -- default
		field_goals_made                  INT,
		field_goals_attempted             INT,
		three_point_field_goals_made      INT,
		three_point_field_goals_attempted INT,
        free_throws_made                  INT,
        free_throws_attempted             INT,
        rebounds_offensive                INT,
        rebounds_defensive                INT,
		assists                           INT,
        fouls_personal                    INT,
		steals                            INT,
        turnovers                         INT,
	    blocks                            INT,
		points                            INT,
		-- calculated
		[minutes-played]                     INT,
		[field-goals-percentage]             VARCHAR(100),
		[three-point-field-goals-percentage] VARCHAR(100),
        [free-throws-percentage]             VARCHAR(100),
        -- display
		[field-goals-made-attempted]             VARCHAR(100),
        [three-point-field-goals-made-attempted] VARCHAR(100),
        [free-throws-made-attempted]             VARCHAR(100),
		[rebounds-total]                         INT,
		[status]                                 VARCHAR(100)
	)

	INSERT INTO @basketball (player_key, team_key, games_started, seconds_played, [position-event],
	                         field_goals_made, field_goals_attempted, three_point_field_goals_made, three_point_field_goals_attempted,
	                         free_throws_made, free_throws_attempted, rebounds_offensive, rebounds_defensive, assists,
	                         fouls_personal, steals, turnovers, blocks, points)
    SELECT p.player_key, p.team_key, ISNULL(games_started, 0), ISNULL(seconds_played, 0), [position-event],
	       ISNULL(field_goals_made, 0), ISNULL(field_goals_attempted, 0), ISNULL(three_point_field_goals_made, 0), ISNULL(three_point_field_goals_attempted, 0),
	       ISNULL(free_throws_made, 0), ISNULL(free_throws_attempted, 0), ISNULL(rebounds_offensive, 0), ISNULL(rebounds_defensive, 0), ISNULL(assists, 0),
	       ISNULL(fouls_personal, 0), ISNULL(steals, 0), ISNULL(turnovers, 0), ISNULL(blocks, 0), ISNULL(points, 0)
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (games_started, seconds_played, [position-event],
	                                           field_goals_made, field_goals_attempted, three_point_field_goals_made, three_point_field_goals_attempted,
	                                           free_throws_made, free_throws_attempted, rebounds_offensive, rebounds_defensive, assists,
	                                           fouls_personal, steals, turnovers, blocks, points)) AS p

    -- calculation
    UPDATE @basketball
       SET [minutes-played] = (seconds_played / 60),
           [rebounds-total] = rebounds_offensive + rebounds_defensive,
           [field-goals-made-attempted] = CAST(field_goals_made AS VARCHAR) + '-' + CAST(field_goals_attempted AS VARCHAR),
           [three-point-field-goals-made-attempted] = CAST(three_point_field_goals_made AS VARCHAR) + '-' + CAST(three_point_field_goals_attempted AS VARCHAR),
           [free-throws-made-attempted] = CAST(free_throws_made AS VARCHAR) + '-' + CAST(free_throws_attempted AS VARCHAR)

    UPDATE @basketball           
       SET [field-goals-percentage] = CAST(ROUND((CAST(field_goals_made AS FLOAT) / field_goals_attempted), 2) AS VARCHAR)
     WHERE field_goals_attempted > 0
       
    UPDATE @basketball           
           SET [three-point-field-goals-percentage] = CAST(ROUND((CAST(three_point_field_goals_made AS FLOAT) / three_point_field_goals_attempted), 2) AS VARCHAR)
     WHERE three_point_field_goals_attempted > 0

    UPDATE @basketball           
           SET [free-throws-percentage] = CAST(ROUND((CAST(free_throws_made AS FLOAT) / free_throws_attempted), 2) AS VARCHAR)
     WHERE free_throws_attempted > 0



    UPDATE @basketball
       SET [minutes-played] = NULL
     WHERE player_key = 'team'

	UPDATE b
	   SET b.player_display = CASE
	                              WHEN [position-event] IS NULL THEN s.first_name + ' ' + s.last_name
	                              ELSE s.first_name + ' ' + s.last_name + ' (' + [position-event] + ')'
	                          END
	  FROM @basketball b
	 INNER JOIN dbo.SMG_Players s
		ON s.player_key = b.player_key AND s.player_key <> 'team'

    DELETE @basketball
     WHERE player_key <> 'team' AND player_display IS NULL

    -- head to head
    DECLARE @team_totals TABLE
    (
        team_key VARCHAR(100),
        column_name VARCHAR(100),
        value    VARCHAR(100)
    )
    INSERT INTO @team_totals (team_key, column_name, value)
	SELECT team_key, column_name, value
	  FROM @basketball
   UNPIVOT (value FOR column_name IN ([field-goals-percentage], [three-point-field-goals-percentage], [free-throws-percentage])) AS u
     WHERE player_key = 'team'

    INSERT INTO @team_totals (team_key, column_name, value)
	SELECT team_key, column_name, value
	  FROM @basketball
   UNPIVOT (value FOR column_name IN (assists, [rebounds-total], blocks, steals, turnovers, fouls_personal)) AS u
     WHERE player_key = 'team'
	                                           
    DECLARE @head2head TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display     VARCHAR(100),
        away_value  VARCHAR(100),
        home_value  VARCHAR(100),
        column_name VARCHAR(100)
    )
    IF (@event_status = 'post-event' AND @leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @head2head (display, column_name)
        VALUES ('Field Goal %', 'field-goals-percentage'), ('3PT Field Goal %', 'three-point-field-goals-percentage'),
               ('Free Throw %', 'free-throws-percentage'), ('Assists', 'assists'), ('Rebounds', 'rebounds-total'),
               ('Blocks', 'blocks'), ('Steals', 'steals'), ('Turnovers', 'turnovers'), ('Fouls', 'fouls_personal')

        UPDATE h2h
           SET h2h.away_value = tt.value
          FROM @head2head h2h
         INNER JOIN @team_totals tt
            ON tt.column_name = h2h.column_name AND tt.team_key = @away_team_key

        UPDATE h2h
           SET h2h.home_value = tt.value
          FROM @head2head h2h
         INNER JOIN @team_totals tt
            ON tt.column_name = h2h.column_name AND tt.team_key = @home_team_key

        UPDATE @head2head
           SET away_value = CAST(away_value AS FLOAT) * 100, home_value = CAST(home_value AS FLOAT) * 100
         WHERE column_name IN ('field-goals-percentage', 'three-point-field-goals-percentage', 'free-throws-percentage')
    END


	-- Display Column Status suppression
	IF (@eventID <> '999999999')
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = c.table_name AND s.column_name = c.column_name
		 WHERE s.platform = 'DES' AND s.page = 'boxscore' AND s.league_name = @leagueName
		   AND display_status = 'hidden'
	END


	SELECT @officials AS officials,
	(
		SELECT t.table_name, t.table_display,
			   (
				   SELECT c.column_name, c.column_display, c.tooltip
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   (
				   SELECT f.column_name, f.column_span
					 FROM @footer f
					WHERE f.table_name = t.table_name
					ORDER BY f.id ASC
					  FOR XML PATH('footer'), TYPE
			   ),
			   (
				   SELECT player_display, [status], [minutes-played],
				          [field-goals-made-attempted], [three-point-field-goals-made-attempted], [free-throws-made-attempted],
                          rebounds_offensive, rebounds_defensive, [rebounds-total], assists, fouls_personal, steals, turnovers, blocks, points
					 FROM @basketball
					WHERE player_key <> 'team' AND team_key = @away_team_key
					ORDER BY games_started DESC, seconds_played DESC, player_display ASC
					  FOR XML PATH('away_team'), TYPE
			   ),
			   (
				   SELECT 'Total' AS player_display, [minutes-played],
				          [field-goals-made-attempted], [three-point-field-goals-made-attempted], [free-throws-made-attempted],
                          rebounds_offensive, rebounds_defensive, [rebounds-total], assists, fouls_personal, steals, turnovers, blocks, points
					 FROM @basketball
					WHERE player_key = 'team' AND team_key = @away_team_key
					  FOR XML PATH('away_total'), TYPE
			   ),
			   (
				   SELECT 'Percentage' AS footer_display, [field-goals-percentage], [three-point-field-goals-percentage], [free-throws-percentage]
					 FROM @basketball
					WHERE player_key = 'team' AND team_key = @away_team_key
					  FOR XML PATH('away_footer'), TYPE
			   ),
			   (
				   SELECT player_display, [status], [minutes-played],
				          [field-goals-made-attempted], [three-point-field-goals-made-attempted], [free-throws-made-attempted],
                          rebounds_offensive, rebounds_defensive, [rebounds-total], assists, fouls_personal, steals, turnovers, blocks, points
					 FROM @basketball
					WHERE player_key <> 'team' AND team_key = @home_team_key 
					ORDER BY games_started DESC, seconds_played DESC, player_display ASC
					  FOR XML PATH('home_team'), TYPE
			   ),
			   (
				   SELECT 'Total' AS player_display, [minutes-played],
				          [field-goals-made-attempted], [three-point-field-goals-made-attempted], [free-throws-made-attempted],
                          rebounds_offensive, rebounds_defensive, [rebounds-total], assists, fouls_personal, steals, turnovers, blocks, points
					 FROM @basketball
					WHERE player_key = 'team' AND team_key = @home_team_key
					  FOR XML PATH('home_total'), TYPE
			   ),
			   (
				   SELECT 'Percentage' AS footer_display, [field-goals-percentage], [three-point-field-goals-percentage], [free-throws-percentage]
					 FROM @basketball
					WHERE player_key = 'team' AND team_key = @home_team_key
					  FOR XML PATH('home_footer'), TYPE
			   )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE			   
	),
    (
        SELECT display, away_value, home_value
          FROM @head2head
         ORDER BY id ASC
           FOR XML PATH('head_to_head'), TYPE
    ),
	(
	    SELECT (
                   SELECT period_value AS periods
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT away_value AS away_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               ),
               (
                   SELECT home_value AS home_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               )
           FOR XML PATH('linescore'), TYPE
    )
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END


GO
