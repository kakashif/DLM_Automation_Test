USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventBoxscore_basketball_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventBoxscore_basketball_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 11/21/2014
-- Description:	get basketball boxscore
-- Update:      07/29/2015 - John Lin - SDI migration
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

    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status, @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 


    IF (@event_status NOT IN ('mid-event', 'intermission', 'weather-delay', 'post-event'))
    BEGIN
        SELECT
	    (
            SELECT '' AS boxscore
               FOR XML PATH(''), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

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
    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
	DECLARE @status_order TABLE
    (
        [order]  INT IDENTITY(1, 1) PRIMARY KEY,
        [status] VARCHAR(100)
    )
    
	INSERT INTO @status_order ([status])
	VALUES ('starter'), ('bench'), ('unknown')

    INSERT INTO @tables (table_name, table_display)
    VALUES ('default', 'Player Stats')
        
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('default', 'player_display', 'PLAYER'), ('default', 'time_played_total', 'MIN'),
		   ('default', 'points_scored_total', 'PTS'), ('default', 'rebounds_total', 'REB'), ('default', 'assists_total', 'AST'),
		   ('default', 'steals_total', 'STL'), ('default', 'blocks_total', 'BLK')
    
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_basketball
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND
           event_key = @event_key AND [column] IN ('position-event', 'status', 'time-played-total', 'field-goals-percentage', 
                                                   'three-pointers-percentage', 'free-throws-percentage', 'points-scored-total',
                                                   'rebounds-total', 'assists-total', 'steals-total', 'blocks-total','personal-fouls', 
                                                   'turnovers-total')

	DECLARE @basketball TABLE
	(
		team_key            VARCHAR(100),
		player_key          VARCHAR(100),
		player_display      VARCHAR(100),
		[status]            VARCHAR(100),
		position_event      VARCHAR(100),
		time_played_total   VARCHAR(100),
		points_scored_total INT,
		rebounds_total      INT,
		assists_total       INT,
		steals_total        INT,
		blocks_total        INT
	)		
	INSERT INTO @basketball (player_key, team_key, [status], position_event, time_played_total, points_scored_total, rebounds_total,
	                         assists_total, steals_total, blocks_total)
    SELECT p.player_key, p.team_key, [status], UPPER(LEFT(position_event, 1)), time_played_total, points_scored_total, rebounds_total,
           assists_total, steals_total, blocks_total
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN ([status], position_event, time_played_total, points_scored_total, rebounds_total,
                                               assists_total, steals_total, blocks_total)) AS p


    -- player
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


    IF (@event_status <> 'post-event')
    BEGIN
        DELETE @columns
         WHERE column_name = 'time_played_total'
    END


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
	(
		SELECT 'true' AS 'json:Array',
		       t.table_name, t.table_display,
			   (
				   SELECT c.column_name, c.column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML RAW('columns'), TYPE
			   ),
			   -- away
			   (
				   SELECT player_display, b.status, time_played_total, points_scored_total, rebounds_total, assists_total, steals_total, blocks_total
					 FROM @basketball AS b
					INNER JOIN @status_order AS so ON so.[status] = ISNULL(b.[status], 'unknown')
					WHERE team_key = @away_team_key
					ORDER BY so.[order] ASC, time_played_total DESC, player_display ASC
					   FOR XML RAW('away_team'), TYPE
			   ),
			   (
				   SELECT 'Total' AS player_display,
						  SUM(points_scored_total) AS points_scored_total, 
						  SUM(rebounds_total) AS rebounds_total,
						  SUM(assists_total) AS assists_total,
						  SUM(steals_total) AS steals_total,
						  SUM(blocks_total) AS blocks_total
					 FROM @basketball
					WHERE team_key = @away_team_key
					   FOR XML RAW('away_total'), TYPE
			   ),
			   -- home
			   (
				   SELECT player_display, b.status, time_played_total, points_scored_total, rebounds_total, assists_total, steals_total, blocks_total
					 FROM @basketball AS b
					INNER JOIN @status_order AS so ON so.[status] = ISNULL(b.[status], 'unknown')
					WHERE team_key = @home_team_key
					ORDER BY so.[order] ASC, time_played_total DESC, player_display ASC
					  FOR XML RAW('home_team'), TYPE
			   ),
			   (
				   SELECT 'Total' AS player_display,
					 	  SUM(points_scored_total) AS points_scored_total, 
						  SUM(rebounds_total) AS rebounds_total,
						  SUM(assists_total) AS assists_total,
						  SUM(steals_total) AS steals_total,
    					  SUM(blocks_total) AS blocks_total
					 FROM @basketball
					WHERE team_key = @home_team_key
					  FOR XML RAW('home_total'), TYPE
			   )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML RAW('boxscore'), TYPE			   
	)
	FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
