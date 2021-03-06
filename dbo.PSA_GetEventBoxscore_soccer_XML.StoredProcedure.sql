USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_soccer_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_soccer_XML]
	@leagueName VARCHAR(100),
    @seasonKey INT,
    @eventKey VARCHAR(100),
    @teamKey VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/11/2014
-- Description: get event boxscore
-- Update:		09/12/2014 - John Lin - add goalkeeper and change substitutes as array
-- 				09/19/2014 - ikenticus - add EPL/Champions fixes like positionId mapping
--				09/30/2014 - ikenticus - deleting GK/fielders/substitutes when missing player stats
--				10/02/2014 - ikenticus - updating GK player-stats
-- 				10/07/2014 - ikenticus: commenting out possession
--				12/22/2014 - ikenticus: set @total display to zero when null
--				05/15/2015 - ikenticus: conditional team_names until we sort out the discrepancies
--				08/13/2015 - ikenticus: adding SDI logic
--				09/29/2015 - ikenticus: adding SDI logic for Starter and Substitution
--				10/20/2015 - ikenticus: updating suppression logic in preparation for CMS tool
--				10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @team_name VARCHAR(100)

	SELECT @team_name = CASE
						WHEN team_first = '' AND team_last <> '' THEN team_last
						WHEN team_first <> '' AND team_last = '' THEN team_first
						WHEN team_first = team_last THEN team_first
						ELSE team_first + ' ' + team_last END
	  FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @teamKey

    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100)
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
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )

    INSERT INTO @tables (table_name)
    VALUES ('goalkeeper'), ('fielders')

    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('goalkeeper', 'player_display', 'GOALKEEPER'),
           ('goalkeeper', 'goals_against_total', 'GA'),
           ('goalkeeper', 'saves', 'SAVES'),
           ('goalkeeper', 'shots_on_goal_against_total', 'SA'),

           ('fielders', 'player_display', 'FIELDERS'),
           ('fielders', 'goals_total', 'G'),
           ('fielders', 'assists_total', 'A'),
           ('fielders', 'fouls_committed', 'FOULS')

    INSERT INTO @stats (player_key, column_name, value)
    SELECT player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_soccer
     WHERE event_key = @eventKey AND team_key = @teamKey AND
           [column] IN ('position-event', 'status', 'substitute',
                        'goals-against-total', 'saves', 'save_pct', 'shots-on-goal-against-total',
                        'goals-total', 'assists-total', 'fouls-committed',
                        'minutes_played', 'shots-total', 'shots-on-goal-total',
						'possession-percentage')

	DECLARE @soccer TABLE
	(
		player_key     VARCHAR(100),
		player_display VARCHAR(100),
		position_event VARCHAR(100),
		minutes_played INT,
		-- goalkeeper
		saves INT,
		save_pct FLOAT,
		goals_against_total INT,
		shots_on_goal_against_total INT,
		-- fielders
		goals_total INT,
		assists_total INT,
		fouls_committed INT,
		-- extra
        [status] VARCHAR(100),
        substitute VARCHAR(100),
		-- teams
		possession_percentage FLOAT,
		shots_total INT,
		shots_on_goal_total INT
	)
	INSERT INTO @soccer (player_key, position_event, [status], substitute,
	                     goals_against_total, saves, save_pct, shots_on_goal_against_total,
                         goals_total, assists_total, fouls_committed, minutes_played,
                         possession_percentage, shots_total, shots_on_goal_total)
    SELECT p.player_key, position_event, [status], substitute,
           goals_against_total, saves, save_pct, shots_on_goal_against_total,
           goals_total, assists_total, fouls_committed, minutes_played,
           possession_percentage, shots_total, shots_on_goal_total
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (position_event, [status], substitute,
                                               goals_against_total, saves, save_pct, shots_on_goal_against_total,
                                               goals_total, assists_total, fouls_committed, minutes_played,
                                               possession_percentage, shots_total, shots_on_goal_total)) AS p

	IF NOT EXISTS (SELECT 1 FROM @soccer WHERE shots_on_goal_against_total IS NOT NULL)
	BEGIN
		UPDATE @soccer
		   SET shots_on_goal_against_total = saves / save_pct
	END

    -- extract out total
	DECLARE @total TABLE
	(
        id INT IDENTITY(1, 1) PRIMARY KEY,
        category VARCHAR(100),
    	display VARCHAR(100)
	)

	INSERT INTO @total (category, display)
    SELECT 'Possession', CAST(possession_percentage AS VARCHAR) + '%'
	  FROM @soccer
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Goal attempts', shots_total
	  FROM @soccer
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Shots on goal', shots_on_goal_total
	  FROM @soccer
	 WHERE player_key = 'team'

	UPDATE @total
	   SET display = 0
	 WHERE display IS NULL

                                              
    -- PLAYER
    UPDATE @soccer
	   SET position_event = CASE
	                            WHEN position_event = '1' THEN 'GK'
	                            WHEN position_event = '2' THEN 'D'
	                            WHEN position_event = '3' THEN 'M'
	                            WHEN position_event = '4' THEN 'F'
	                            WHEN position_event = '5' THEN 'FC'
	                            ELSE position_event
	                        END
	WHERE position_event IS NOT NULL

	UPDATE s
	   SET position_event = position_regular
	  FROM @soccer AS s
	 INNER JOIN SportsDB.dbo.SMG_Rosters AS r
		ON r.team_key = @teamKey AND r.player_key = s.player_key
	 WHERE s.position_event IS NULL

	UPDATE s
	   SET player_display = (CASE
	                              WHEN LEN(p.first_name) = 0 AND s.position_event IS NULL THEN p.last_name
	                              WHEN s.position_event IS NULL THEN LEFT(p.first_name, 1) + '. ' + p.last_name
	                              WHEN LEN(p.first_name) = 0 THEN p.last_name + ' (' + s.position_event + ')'
	                              ELSE LEFT(p.first_name, 1) + '. ' + p.last_name + ' (' + s.position_event + ')'
	                           END)
	  FROM @soccer AS s
	 INNER JOIN SportsDB.dbo.SMG_Players AS p
		ON p.player_key = s.player_key AND p.first_name <> 'TEAM'

    DELETE @soccer
     WHERE player_display IS NULL

	UPDATE @soccer
	   SET goals_total = 0
	 WHERE goals_total IS NULL

	UPDATE @soccer
	   SET assists_total = 0
	 WHERE assists_total IS NULL

	UPDATE @soccer
	   SET fouls_committed = 0
	 WHERE fouls_committed IS NULL

	UPDATE @soccer
	   SET saves = 0
	 WHERE saves IS NULL

	UPDATE @soccer
	   SET goals_against_total = 0
	 WHERE goals_against_total IS NULL

	UPDATE @soccer
	   SET shots_on_goal_against_total = 0
	 WHERE shots_on_goal_against_total IS NULL


    -- goalkeeper
    DECLARE @goalkeeper TABLE
    (
        player_display VARCHAR(100),
		saves INT,
		goals_against_total INT,
		shots_on_goal_against_total INT
    )

	INSERT INTO @goalkeeper (player_display, goals_against_total, saves, shots_on_goal_against_total)
	SELECT player_display, goals_against_total, saves, shots_on_goal_against_total
	  FROM @soccer
     WHERE position_event IN ('GK', 'G') AND minutes_played IS NOT NULL

	IF (NOT EXISTS(SELECT 1 FROM @goalkeeper) AND @eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'goalkeeper'
		DELETE FROM @tables WHERE table_name = 'goalkeeper'
	END


    -- fielders
    DECLARE @fielders TABLE
    (
        player_display  VARCHAR(100),
		goals_total     INT,
		assists_total   INT,
		fouls_committed INT
    )

	INSERT INTO @fielders (player_display, goals_total, assists_total, fouls_committed)
	SELECT player_display, goals_total, assists_total, fouls_committed
	  FROM @soccer
     WHERE position_event NOT IN ('GK', 'G') AND minutes_played IS NOT NULL



	-- SUBSTITUTES
	DECLARE @substitutes TABLE (
        player_key       VARCHAR(100),
        player_display   VARCHAR(100),
        position_regular VARCHAR(100)
	)

	INSERT INTO @substitutes (player_display)
	SELECT player_display
	  FROM @soccer
     WHERE status = 'Substitution' AND minutes_played IS NULL

	-- retrieve from rosters only if not available in events
	IF NOT EXISTS (SELECT 1 FROM @substitutes)
	BEGIN
		INSERT INTO @substitutes (player_key, position_regular)
		SELECT player_key, position_regular
		  FROM dbo.SMG_Rosters
		 WHERE team_key = @teamKey AND season_key = @seasonKey AND phase_status <> 'delete'

		DELETE FROM @substitutes
		 WHERE player_key IN (SELECT player_key FROM @soccer)

		UPDATE @substitutes
		   SET position_regular = CASE
									WHEN position_regular = '1' THEN 'GK'
									WHEN position_regular = '2' THEN 'D'
									WHEN position_regular = '3' THEN 'M'
									WHEN position_regular = '4' THEN 'F'
									WHEN position_regular = '5' THEN 'FC'
									ELSE position_regular
								END
		WHERE position_regular IS NOT NULL

		UPDATE b
		   SET b.player_display = (CASE
									  WHEN LEN(s.first_name) = 0 THEN s.last_name + ' (' + b.position_regular + ')'
									  ELSE LEFT(s.first_name, 1) + '. ' + s.last_name + ' (' + b.position_regular + ')'
								   END)
		  FROM @substitutes AS b
		 INNER JOIN SportsDB.dbo.SMG_Players AS s
			ON s.player_key = b.player_key AND s.first_name <> 'TEAM'
	END

	IF (NOT EXISTS(SELECT 1 FROM @fielders) AND @eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'fielders'
		DELETE FROM @tables WHERE table_name = 'fielders'
		DELETE FROM @substitutes
	END


	-- Display Column Status suppression
	IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = c.table_name AND s.column_name = c.column_name
		 WHERE s.platform = 'PSA' AND s.page = 'boxscore' AND s.league_name = @leagueName
		   AND display_status = 'hidden'
	END


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @team_name AS team_name,
	(
		SELECT 'true' AS 'json:Array',
		       t.table_name,
			   (
				   SELECT c.column_name, c.column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
               (
                   SELECT player_display, goals_against_total, saves, shots_on_goal_against_total
                     FROM @goalkeeper
                    WHERE player_display <> 'TEAM' AND t.table_name = 'goalkeeper'
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, goals_total, assists_total, fouls_committed
                     FROM @fielders
                    WHERE player_display <> 'TEAM' AND t.table_name = 'fielders'
                    ORDER BY goals_total DESC, assists_total DESC, fouls_committed ASC
                      FOR XML PATH('rows'), TYPE
               )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML RAW('boxscore'), TYPE
	),
	(
   	    SELECT category, display
		  FROM @total
		 ORDER BY id ASC
		   FOR XML RAW('total'), TYPE
	),
	(
	   -- return as array
   	    SELECT player_display AS substitutes
		  FROM @substitutes
		   FOR XML PATH(''), TYPE
	)
	FOR XML PATH(''), ROOT('root')			   
        
    SET NOCOUNT OFF;
END

GO
