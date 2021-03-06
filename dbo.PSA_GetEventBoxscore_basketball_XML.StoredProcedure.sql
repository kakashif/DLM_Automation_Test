USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_basketball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_basketball_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventKey VARCHAR(100),
    @teamKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/27/2014
-- Description: get event boxscore
-- Update: 10/08/2014 - John Lin - change time_played_total to varchar
--         10/21/2014 - John Lin - change text TEAM to TOTAL
--         11/13/2014 - John Lin - suppress time played total till post event
--         10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @team_name VARCHAR(100)
    DECLARE @time_played_total VARCHAR(100) = '-'
    
	SELECT @team_name = team_first + ' ' + team_last
	  FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @teamKey

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
          
    INSERT INTO @columns (column_name, column_display)
    VALUES ('player_display', 'PLAYER'), ('time_played_total', 'MIN'),
           ('points_scored_total', 'PTS'), ('rebounds_total', 'REB'), ('assists_total', 'AST')
    
    INSERT INTO @stats (player_key, column_name, value)
    SELECT player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_basketball
     WHERE event_key = @eventKey AND team_key = @teamKey AND
           [column] IN ('position-event', 
                        'time-played-total', 'points-scored-total', 'rebounds-total', 'assists-total',
                        'field-goals-attempted', 'field-goals-made', 'field-goals-percentage',
                        'three-pointers-attempted', 'three-pointers-made', 'three-pointers-percentage',
                        'free-throws-attempted', 'free-throws-made', 'free-throws-percentage',
                        'turnovers-total', 'status')

	DECLARE @basketball TABLE
	(
		player_key                VARCHAR(100),
		player_display            VARCHAR(100),
		position_event            VARCHAR(100),
		time_played_total         VARCHAR(100),
		points_scored_total       INT,
		-- shared
		rebounds_total            INT,
		assists_total             INT,
		-- team
		field_goals_attempted     VARCHAR(100),
		field_goals_made          VARCHAR(100),
		field_goals_percentage    VARCHAR(100),
		three_pointers_attempted  VARCHAR(100),
		three_pointers_made       VARCHAR(100),
		three_pointers_percentage VARCHAR(100),
		free_throws_attempted     VARCHAR(100),
		free_throws_made          VARCHAR(100),
		free_throws_percentage    VARCHAR(100),
		turnovers_total           VARCHAR(100),
        [status]                  VARCHAR(100)
	)
	INSERT INTO @basketball (player_key, position_event,
	                         time_played_total, points_scored_total, rebounds_total, assists_total,
		                     field_goals_attempted, field_goals_made, field_goals_percentage,
		                     three_pointers_attempted, three_pointers_made, three_pointers_percentage,
		                     free_throws_attempted, free_throws_made, free_throws_percentage,
		                     turnovers_total, [status])
    SELECT p.player_key, position_event,
           time_played_total, points_scored_total, rebounds_total, assists_total,
		   field_goals_attempted, field_goals_made, field_goals_percentage,
		   three_pointers_attempted, three_pointers_made, three_pointers_percentage,
		   free_throws_attempted, free_throws_made, free_throws_percentage,
		   turnovers_total, [status]
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (position_event,
                                               time_played_total, points_scored_total, rebounds_total, assists_total,
     		                                   field_goals_attempted, field_goals_made, field_goals_percentage,
     		                                   three_pointers_attempted, three_pointers_made, three_pointers_percentage,
     		                                   free_throws_attempted, free_throws_made, free_throws_percentage,
     		                                   turnovers_total, [status])) AS p

    -- extract out total
	DECLARE @total TABLE
	(
        id INT IDENTITY(1, 1) PRIMARY KEY,
        category VARCHAR(100),
    	display VARCHAR(100),
    	percentage VARCHAR(100)
	)
	
	INSERT INTO @total (category, display, percentage)
    SELECT 'Field Goal %', '(' + field_goals_made + ' of ' + field_goals_attempted + ')',
           CAST(ROUND(CAST(field_goals_percentage AS FLOAT) * 100, 0) AS VARCHAR) + '%'
	  FROM @basketball
	 WHERE player_key = 'team'
	 
	INSERT INTO @total (category, display, percentage)
    SELECT '3pt Field Goal %', '(' + three_pointers_made + ' of ' + three_pointers_attempted + ')',
           CAST(ROUND(CAST(three_pointers_percentage AS FLOAT) * 100, 0) AS VARCHAR) + '%'
	  FROM @basketball
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display, percentage)
    SELECT 'Free Throw %', '(' + free_throws_made + ' of ' + free_throws_attempted + ')',
           CAST(ROUND(CAST(free_throws_percentage AS FLOAT) * 100, 0) AS VARCHAR) + '%'
	  FROM @basketball
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Assists', assists_total
	  FROM @basketball
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Rebounds', rebounds_total
	  FROM @basketball
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Turnovers', turnovers_total
	  FROM @basketball
	 WHERE player_key = 'team'


    -- PLAYER
    UPDATE @basketball
	   SET position_event = CASE
	                            WHEN position_event = 'center' THEN 'C'
	                            WHEN position_event = 'forward' THEN 'F'
	                            WHEN position_event = 'guard' THEN 'G'
	                            ELSE position_event
	                        END
	WHERE position_event IS NOT NULL
     
	UPDATE b
	   SET b.player_display = (CASE
	                              WHEN b.position_event IS NULL THEN LEFT(s.first_name, 1) + '. ' + s.last_name
	                              ELSE LEFT(s.first_name, 1) + '. ' + s.last_name + ' (' + b.position_event + ')'
	                           END)
	  FROM @basketball AS b
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = b.player_key AND s.first_name <> 'TEAM'


    DELETE @basketball
     WHERE player_display IS NULL

    DELETE @basketball
     WHERE [status] IS NULL OR [status] NOT IN ('starter', 'bench')
     
    UPDATE @basketball
	   SET [status] = CASE WHEN [status] = 'starter' THEN '1' ELSE '2' END


    IF NOT EXISTS(SELECT 1 FROM @basketball WHERE time_played_total IS NOT NULL)
    BEGIN
        DELETE @columns
         WHERE column_name = 'time_played_total'

        SET @time_played_total = NULL
    END


	-- Display Column Status suppression
	IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = 'player' AND s.column_name = c.column_name
		 WHERE s.platform = 'PSA' AND s.page = 'boxscore' AND s.league_name = @leagueName
		   AND display_status = 'hidden'
	END


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @team_name AS team_name,
	(
		SELECT 'true' AS 'json:Array',
		       'player' AS table_name,
			   (
	               SELECT column_name, column_display
		             FROM @columns
		            ORDER BY id ASC
		              FOR XML RAW('columns'), TYPE
			   ),
			   (
	               SELECT player_display, time_played_total, points_scored_total, rebounds_total, assists_total
		             FROM @basketball
		            WHERE player_key <> 'team'
		            ORDER BY CAST([status] AS INT) ASC, time_played_total DESC, player_display ASC
		              FOR XML RAW('rows'), TYPE
			   ),
			   (
	               SELECT 'TOTAL' AS player_display, @time_played_total AS time_played_total, SUM(points_scored_total) AS points_scored_total,
	                      SUM(rebounds_total) AS rebounds_total, SUM(assists_total) AS assists_total
		             FROM @basketball
		            WHERE player_key <> 'team'
		              FOR XML RAW('total'), TYPE
			   )
		   FOR XML RAW('boxscore'), TYPE
	),
	(
   	    SELECT category, display, percentage
		  FROM @total
		 ORDER BY id ASC
		   FOR XML RAW('total'), TYPE
	)
	FOR XML PATH(''), ROOT('root')			   
        
    SET NOCOUNT OFF;
END

GO
