USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_soccer_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_soccer_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	06/01/2015
-- Description:	get boxscore for desktop for soccer
-- Update:		06/08/2015 - ikenticus - correcting head2head logic
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--				09/03/2015 - ikenticus: adding SDI logic
--				09/17/2015 - ikenticus: adding recap logic
--				10/21/2015 - ikenticus: updating suppression logic in preparation for CMS tool
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
	DECLARE @date_time VARCHAR(100)
    DECLARE @recap VARCHAR(100)
    
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

    -- LINESCORE
    DECLARE @linescore TABLE
    (
        period INT,
        period_value VARCHAR(100),
        away_value VARCHAR(100),
        home_value VARCHAR(100)
    )
    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key
     
    -- BOXSCORE
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
        column_display VARCHAR(100),
        tooltip        VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )

    INSERT INTO @tables (table_name, table_display)
    VALUES ('goalkeeper', 'goalkeeper'), ('fielders', 'fielders')
        
    INSERT INTO @columns (table_name, column_name, column_display, tooltip)
    VALUES ('goalkeeper', 'player_display', 'PLAYER', 'Player'),
           ('goalkeeper', 'goals-against-total', 'GA', 'Goal Against'),
           ('goalkeeper', 'saves', 'SAVES', 'Saves'),
           ('goalkeeper', 'shots-on-goal-total', 'SA', 'Shots Against'),

           ('fielders', 'player_display', 'PLAYER', 'Player'),
           ('fielders', 'goals-total', 'G', 'Goals'),
           ('fielders', 'assists-total', 'A', 'Assists'),
           ('fielders', 'fouls-committed', 'FOULS', 'Fouls')

    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_soccer
     WHERE season_key = @seasonKey AND sub_season_type = @sub_season_type AND event_key = @event_key

	DECLARE @soccer TABLE
	(
		team_key VARCHAR(100),
		player_key VARCHAR(100),
        player_display VARCHAR(100),
		[position-event] VARCHAR(100),
		--goalkeeper
		[saves] INT,
		[goals-against-total] INT,
		[shots-on-goal-total] INT,
		-- fielders
		[goals-total] INT,
		[assists-total] INT,
		[fouls-committed] INT
	)

	INSERT INTO @soccer (player_key, team_key, [position-event],
	                     [saves], [goals-against-total], [shots-on-goal-total],
		                 [goals-total], [assists-total], [fouls-committed])
    SELECT p.player_key, p.team_key, [position-event],
    	   ISNULL([saves], 0), ISNULL([goals-against-total], 0), ISNULL([shots-on-goal-total], 0),
		   ISNULL([goals-total], 0), ISNULL([assists-total], 0), ISNULL([fouls-committed], 0)
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN ([position-event],
	                                           [saves], [goals-against-total], [shots-on-goal-total],
		                                       [goals-total], [assists-total], [fouls-committed])) AS p

    -- position
    UPDATE @soccer
	   SET [position-event] = CASE
	                            WHEN [position-event] = '1' THEN 'GK'
	                            WHEN [position-event] = '2' THEN 'D'
	                            WHEN [position-event] = '3' THEN 'M'
	                            WHEN [position-event] = '4' THEN 'F'
	                            WHEN [position-event] = '5' THEN 'FC'
	                            ELSE [position-event]
	                        END
	WHERE [position-event] IS NOT NULL

	UPDATE s
	   SET [position-event] = position_regular
	  FROM @soccer AS s
	 INNER JOIN SportsDB.dbo.SMG_Rosters AS r ON r.team_key = s.team_key AND r.player_key = s.player_key
	 WHERE s.[position-event] IS NULL

    -- player
	UPDATE s
	   SET s.player_display = CASE
	                              WHEN [position-event] NOT IN ('G', 'GK') THEN p.first_name + ' ' + p.last_name + ' (' + [position-event] + ')'
	                              ELSE p.first_name + ' ' + p.last_name
	                          END
	  FROM @soccer s
	 INNER JOIN dbo.SMG_Players p
		ON s.player_key = p.player_key AND p.first_name <> 'TEAM'

    -- goalkeeper
    DECLARE @goalkeeper TABLE
    (
        team_key VARCHAR(100),
        player_display VARCHAR(100),
		[saves] INT,
		[goals-against-total] INT,
		[shots-on-goal-total] INT
    )
	INSERT INTO @goalkeeper (team_key, player_display, [saves], [goals-against-total], [shots-on-goal-total])
	SELECT team_key, player_display, [saves], [goals-against-total], [shots-on-goal-total]
	  FROM @soccer
     WHERE player_key <> 'team' AND [position-event] IN ('G', 'GK')

    UPDATE @goalkeeper
       SET [saves] = ISNULL([saves], 0),
           [goals-against-total] = ISNULL([goals-against-total], 0),
           [shots-on-goal-total] = ISNULL([shots-on-goal-total], 0)

	IF EXISTS (SELECT 1 FROM @goalkeeper)
	BEGIN
		INSERT INTO @goalkeeper (team_key, player_display, [saves], [goals-against-total], [shots-on-goal-total])
		SELECT @away_team_key, 'TEAM', SUM([saves]), SUM([goals-against-total]), SUM([shots-on-goal-total])
		  FROM @goalkeeper
		 WHERE team_key = @away_team_key 

		INSERT INTO @goalkeeper (team_key, player_display, saves, [goals-against-total], [shots-on-goal-total])
		SELECT @home_team_key, 'TEAM', SUM([saves]), SUM([goals-against-total]), SUM([shots-on-goal-total])
		  FROM @goalkeeper
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'goalkeeper'
	END

    -- fielders
    DECLARE @fielders TABLE
    (
        team_key VARCHAR(100),
        player_display VARCHAR(100),
		[goals-total] INT,
		[assists-total] INT,
		[fouls-committed] INT
    )
	INSERT INTO @fielders (team_key, player_display, [goals-total], [assists-total], [fouls-committed])
	SELECT team_key, player_display, [goals-total], [assists-total], [fouls-committed]
	  FROM @soccer
     WHERE player_key <> 'team' AND [position-event] NOT IN ('G', 'GK')

    UPDATE @fielders
       SET [goals-total] = ISNULL([goals-total], 0),
           [assists-total] = ISNULL([assists-total], 0),
           [fouls-committed] = ISNULL([fouls-committed], 0)

	IF EXISTS (SELECT 1 FROM @fielders)
	BEGIN
		INSERT INTO @fielders (team_key, player_display, [goals-total], [assists-total], [fouls-committed])
		SELECT @away_team_key, 'TEAM', SUM([goals-total]), SUM([assists-total]), SUM([fouls-committed])
		  FROM @fielders
		 WHERE team_key = @away_team_key 

		INSERT INTO @fielders (team_key, player_display, [goals-total], [assists-total], [fouls-committed])
		SELECT @home_team_key, 'TEAM',  SUM([goals-total]), SUM([assists-total]), SUM([fouls-committed])
		  FROM @fielders
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'fielders'
	END

    -- head to head
	DECLARE @head2head TABLE
	(
		id          INT IDENTITY(1, 1) PRIMARY KEY,
		display     VARCHAR(100),
		away_value  VARCHAR(100),
		home_value  VARCHAR(100),
		column_name VARCHAR(100)
	)
   	DECLARE @h2h_stats TABLE
   	(
    	team_key    VARCHAR(100),
	    column_name VARCHAR(100),
		value       VARCHAR(100)
   	)

    INSERT INTO @h2h_stats (team_key, column_name, value)
   	SELECT team_key, column_name, value
   	  FROM @stats
     WHERE player_key = 'team' AND column_name IN ('possession-percentage', 'shots-total', 'shots-on-goal-total', 'offsides', 'fouls-committed', 'corner-kicks')

    IF EXISTS (SELECT 1 FROM @h2h_stats)
    BEGIN
        INSERT INTO @head2head (display, column_name)
	    VALUES ('Goal Attempts', 'shots-total'), ('Shots On Goal', 'shots-on-goal-total'), 
               ('Corner Kicks', 'corner-kicks'), ('Fouls', 'fouls-committed'), ('Offsides', 'offsides')

    	UPDATE h2h
	       SET h2h.away_value = tt.value
		  FROM @head2head h2h
    	 INNER JOIN @h2h_stats tt
	    	ON tt.column_name = h2h.column_name AND tt.team_key = @away_team_key

	    UPDATE h2h
	       SET h2h.home_value = tt.value
	      FROM @head2head h2h
	     INNER JOIN @h2h_stats tt
		    ON tt.column_name = h2h.column_name AND tt.team_key = @home_team_key

        UPDATE @head2head
    	   SET away_value = 0
         WHERE away_value IS NULL

        UPDATE @head2head
	       SET home_value = 0
         WHERE home_value IS NULL
    END

    -- DATETIME
	SELECT TOP 1 @date_time = date_time
		  FROM SportsDB.dbo.SMG_Scores
		 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key
	ORDER BY date_time DESC

	IF (@event_status = 'post-event')
	BEGIN
		-- Recap
		SELECT @recap = '/sports/soccer/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/recap/'
		  FROM SportsDB.dbo.SMG_Scores
		 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key AND column_type = 'post-event-coverage'
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

    SELECT @officials AS officials, @recap AS recap,
	(
		SELECT t.table_name, t.table_display,
			   (
				   SELECT c.column_name, c.column_display, c.tooltip
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   -- away
               (
                   SELECT player_display, [saves], [goals-against-total], [shots-on-goal-total]
                     FROM @goalkeeper
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'goalkeeper'
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, [saves], [goals-against-total], [shots-on-goal-total]
                     FROM @goalkeeper
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'goalkeeper'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, [goals-total], [assists-total], [fouls-committed]
                     FROM @fielders
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'fielders'
                    ORDER BY [goals-total] DESC, [assists-total] DESC, [fouls-committed] ASC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, [goals-total], [assists-total], [fouls-committed]
                     FROM @fielders
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'fielders'
                      FOR XML PATH('away_total'), TYPE
               ),
			   -- home
               (
                   SELECT player_display, [saves], [goals-against-total], [shots-on-goal-total]
                     FROM @goalkeeper
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'goalkeeper'
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, [saves], [goals-against-total], [shots-on-goal-total]
                     FROM @goalkeeper
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'goalkeeper'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, [goals-total], [assists-total], [fouls-committed]
                     FROM @fielders
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'fielders'
                    ORDER BY [goals-total] DESC, [assists-total] DESC, [fouls-committed] ASC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, [goals-total], [assists-total], [fouls-committed]
                     FROM @fielders
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'fielders'
                      FOR XML PATH('home_total'), TYPE
               )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE
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
    ),
    (
        SELECT display, away_value, home_value
          FROM @head2head
         ORDER BY id ASC
           FOR XML PATH('head_to_head'), TYPE
    ),
	(
		SELECT @date_time        
           FOR XML PATH('updated_date'), TYPE
	)

	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END


GO
