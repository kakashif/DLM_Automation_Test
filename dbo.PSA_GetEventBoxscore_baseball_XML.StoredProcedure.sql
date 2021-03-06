USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_baseball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_baseball_XML]
    @seasonKey INT, 
    @eventKey VARCHAR(100),
    @teamKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/09/2014
-- Description: get event boxscore
-- Update:      09/09/2014 - ikenticus: fixing position-event
--				10/14/2014 - ikenticus: removing (P) from pitchers and adding leaders stat
--              10/21/2014 - John Lin - change text TEAM to TOTAL
--				10/25/2014 - ikenticus - SOC-111: display all batters from game
--				04/09/2015 - ikenticus - SOC-211: placing TOTAL on bottom, adding BB and SO to pitching
--				04/10/2015 - ikenticus - removing BB until iOS can be adjusted to display more columns
--				08/28/2015 - ikenticus - SDI migration
--				08/31/2015 - ikenticus - fixing zero at-bats with .000 average pinch hitting
--				10/08/2015 - ikenticus - fixing empty era with 0.00
--				10/22/2015 - ikenticus - fixing BA/ERA formatting when no season data yet, removing TSN position mapping, batting/pitching display
--				10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @team_name VARCHAR(100)

	SELECT @team_name = team_first + ' ' + team_last
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
    VALUES ('batting'), ('pitching')
        
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('batting', 'player_display', 'BATTING'),
           ('batting', 'at_bats', 'AB'),
           ('batting', 'runs_scored', 'R'),
           ('batting', 'hits', 'H'),
           ('batting', 'rbi', 'RBI'), 
           ('batting', 'average', 'AVG'),
		   ('pitching', 'player_display', 'PITCHING'),
		   ('pitching', 'innings_pitched', 'IP'),
		   ('pitching', 'pitching_hits', 'H'),
		   ('pitching', 'runs_allowed', 'R'),
		   ('pitching', 'pitching_bases_on_balls', 'BB'),
		   ('pitching', 'pitching_strikeouts', 'SO'),
		   ('pitching', 'era', 'ERA')

    INSERT INTO @stats (player_key, column_name, value)
    SELECT player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_baseball
     WHERE event_key = @eventKey AND team_key = @teamKey

	DECLARE @baseball TABLE
	(
	    table_name        VARCHAR(100),
		player_key        VARCHAR(100),
	    batting_display    VARCHAR(100),
	    pitching_display    VARCHAR(100),
	    position_event	  VARCHAR(100),
		--batting
		at_bats			  INT,
		runs_scored		  INT,
		hits			  INT,
		rbi				  INT,
        average			  VARCHAR(100),
        batting_average_season VARCHAR(100),
		-- pitching
		innings_pitched	  VARCHAR(100),
		pitching_hits	  INT,
		runs_allowed	  INT,
		era				  VARCHAR(100),
		earned_run_average_season VARCHAR(100),
		pitching_bases_on_balls	 INT,
		pitching_strikeouts		 INT,
		-- extra
	    lineup_slot_sequence     INT,
	    lineup_slot       INT,
	    pitching_order    INT,
		number_of_pitches INT
	)

	INSERT INTO @baseball (player_key, position_event,
	                       at_bats, runs_scored, hits, rbi,
	                       average, innings_pitched, pitching_hits, runs_allowed, era,
	                       pitching_bases_on_balls, pitching_strikeouts,
	                       lineup_slot, lineup_slot_sequence, pitching_order, number_of_pitches,
	                       batting_average_season, earned_run_average_season)
    SELECT p.player_key, (CASE WHEN CHARINDEX(',', position_event) > 0 THEN UPPER(LEFT(position_event, 1)) ELSE UPPER(position_event) END),
           ISNULL(at_bats, 0), ISNULL(runs_scored, 0), ISNULL(hits, 0), ISNULL(rbi, 0),
           average, innings_pitched, ISNULL(pitching_hits, 0), ISNULL(runs_allowed, 0), era,
	       ISNULL(pitching_bases_on_balls, 0), ISNULL(pitching_strikeouts, 0),
           lineup_slot, lineup_slot_sequence, pitching_order, number_of_pitches,
           batting_average_season, earned_run_average_season
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (position_event,
                                               at_bats, runs_scored, hits, rbi,
                                               average, innings_pitched, pitching_hits, runs_allowed, era,
	                                           pitching_bases_on_balls, pitching_strikeouts,
                                               lineup_slot, lineup_slot_sequence, pitching_order, number_of_pitches,
                                               batting_average_season, earned_run_average_season)) AS p

	UPDATE @baseball
	   SET average = batting_average_season
	 WHERE batting_average_season IS NOT NULL

	UPDATE @baseball
	   SET average = REPLACE(CAST(CAST(average AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')
	 WHERE average IS NOT NULL

	UPDATE @baseball
	   SET average = '.000'
	 WHERE average IS NULL

	UPDATE @baseball
	   SET era = earned_run_average_season
	 WHERE earned_run_average_season IS NOT NULL

	UPDATE @baseball
	   SET era = CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR)
	 WHERE era IS NOT NULL

	UPDATE @baseball
	   SET era = '0.00'
	 WHERE era IS NULL

	UPDATE b
	   SET b.pitching_display = LEFT(s.first_name, 1) + '. ' + s.last_name,
		   b.batting_display = (CASE
	                              WHEN b.position_event IS NULL THEN LEFT(s.first_name, 1) + '. ' + s.last_name
	                              ELSE LEFT(s.first_name, 1) + '. ' + s.last_name + ' (' + b.position_event + ')'
	                           END)
	  FROM @baseball AS b
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = b.player_key AND s.first_name <> 'TEAM'

    DELETE @baseball
     WHERE batting_display IS NULL

    -- batting
    DECLARE @batting TABLE
    (
        player_display VARCHAR(100),
        at_bats        INT,
        runs_scored    INT,
        hits           INT,
        rbi            INT,
        average        VARCHAR(100),
        -- extra
        lineup_slot_sequence    INT,
        lineup_slot    INT

    )
	INSERT INTO @batting (player_display, at_bats, runs_scored, hits, rbi, average, lineup_slot, lineup_slot_sequence)
	SELECT batting_display, at_bats, runs_scored, hits, rbi, average, lineup_slot, lineup_slot_sequence
	  FROM @baseball
     WHERE lineup_slot_sequence > 0 OR lineup_slot > 0
            
	INSERT INTO @batting (player_display, at_bats, runs_scored, hits, rbi, average, lineup_slot)
    SELECT 'TOTAL', SUM(at_bats), SUM(runs_scored), SUM(hits), SUM(rbi), '-', 0
      FROM @batting

    -- pitching
    DECLARE @pitching TABLE
    (
        player_display  VARCHAR(100),
        innings_pitched VARCHAR(100),
        pitching_hits   INT,
        runs_allowed    INT,
        era             VARCHAR(100),
		pitching_bases_on_balls	INT,
		pitching_strikeouts		INT,
		-- extra
	    pitching_order    INT,
		ip_first          INT,
		ip_second         INT
    )
	INSERT INTO @pitching (player_display, innings_pitched, pitching_hits, runs_allowed, era, pitching_order, ip_first, ip_second, pitching_bases_on_balls, pitching_strikeouts)
	SELECT pitching_display, innings_pitched, pitching_hits, runs_allowed, era, pitching_order,
	       CAST(CAST(innings_pitched AS DECIMAL(3,1)) AS INT), CAST(RIGHT(CAST(innings_pitched AS DECIMAL(3,1)), 1) AS INT),
           pitching_bases_on_balls, pitching_strikeouts
	  FROM @baseball
     WHERE number_of_pitches IS NOT NULL AND number_of_pitches <> '' AND number_of_pitches > 0

	INSERT INTO @pitching (player_display, pitching_hits, runs_allowed, era, innings_pitched, pitching_order, ip_first, ip_second, pitching_bases_on_balls, pitching_strikeouts)
    SELECT 'TOTAL', SUM(pitching_hits), SUM(runs_allowed), '-', '-', 0,
           (SUM(ip_first) + SUM(ip_second) / 3), (SUM(ip_second) % 3),
		   SUM(pitching_bases_on_balls), SUM(pitching_strikeouts)
      FROM @pitching

	-- Append leader stats to pitchers for W, L, S
	UPDATE p
       SET p.player_display = player_display + (
			CASE 
				WHEN CHARINDEX(' ', stat_value) = 0 THEN REPLACE(stat_value, '(', ' (' + LEFT(player_value, 1) + ', ')
				ELSE REPLACE(LEFT(stat_value, CHARINDEX(' ', stat_value) - 1), '(', ' (' + LEFT(player_value, 1) + ', ')
			END)
	  FROM @pitching AS p
     INNER JOIN dbo.SMG_Events_Leaders AS l ON l.player_value LIKE '%' + RIGHT(player_display, LEN(player_display) - 3)
     WHERE event_key = @eventKey AND team_key = @teamKey AND category = 'PITCHING'


	-- Display Column Status suppression
	IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = c.table_name AND s.column_name = c.column_name
		 WHERE s.platform = 'PSA' AND s.page = 'boxscore' AND s.league_name = 'mlb'
		   AND display_status = 'hidden'
	END


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @team_name AS team_name,
	(
		SELECT 'true' AS 'json:Array',
		       t.table_name,
			   (
				   SELECT c.column_name, column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML RAW('columns'), TYPE
			   ),
			   (
				   SELECT player_display, at_bats, runs_scored, hits, rbi, average
					 FROM @batting
					WHERE player_display <> 'TOTAL' AND t.table_name = 'batting'
					ORDER BY lineup_slot ASC, lineup_slot_sequence ASC
					  FOR XML RAW('rows'), TYPE
			   ),
			   (
				   SELECT player_display, at_bats, runs_scored, hits, rbi, average
					 FROM @batting
					WHERE player_display = 'TOTAL' AND t.table_name = 'batting'
					  FOR XML RAW('total'), TYPE
			   ),
			   (
				   SELECT player_display, innings_pitched,
		                  pitching_bases_on_balls, pitching_strikeouts,
                          pitching_hits, runs_allowed, era
					 FROM @pitching
					WHERE player_display <> 'TOTAL' AND t.table_name = 'pitching'
					ORDER BY pitching_order ASC
					  FOR XML RAW('rows'), TYPE
			   ),
			   (
				   SELECT player_display, CAST(ip_first AS VARCHAR) + '.' + CAST(ip_second AS VARCHAR) AS innings_pitched,
		                  pitching_bases_on_balls, pitching_strikeouts,
                          pitching_hits, runs_allowed, era
					 FROM @pitching
					WHERE player_display = 'TOTAL' AND t.table_name = 'pitching'
					  FOR XML RAW('total'), TYPE
			   )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML RAW('boxscore'), TYPE
	)
	FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
