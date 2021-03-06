USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_football_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventKey VARCHAR(100),
    @teamKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/11/2014
-- Description: get event boxscore
--				09/04/2014 - ikenticus - removing columns for empty boxscore stats
--              10/21/2014 - John Lin - change text TEAM to TOTAL
--				10/24/2014 - ikenticus - adding OLB, changing remaining TEAM to TOTAL
--				10/30/2014 - ikenticus - appending % to percentages
--				11/04/2014 - ikenticus - correcting passing_percentages
--				11/08/2014 - ikenticus - updating rushing/receptions averages/longest
--				11/10/2014 - ikenticus - per SJ-750, % not needed in value; converting % mid-event
--              11/11/2014 - John Lin - modify set position from case to replace
--				             ikenticus - per SJ-843, setting NULL @defense columns to zero
--				11/13/2014 - ikenticus - turnovers = interceptions + fumbles_lost (not committed)
--				11/17/2014 - ikenticus - per SJ-924, fixing mid-event % incorrect when 1.00
--              01/12/2015 - John Lin - order by total yars descenting
--              01/29/2015 - ikenticus - use net for passing, falling back to gross
--              08/05/2015 - John Lin - SDI migration
--              09/28/2015 - John Lin - default null to zero
--              09/29/2015 - ikenticus - removing NFL conditional for @defense
--              10/04/2015 - John Lin - calculate team statistics
--				10/21/2015 - ikenticus: updating suppression logic in preparation for CMS tool
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
    INSERT INTO @tables (table_name)
    VALUES ('passing'), ('rushing'), ('receiving'), ('defense')

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('passing', 'player_display', 'PASSING'),
           ('passing', 'passing_plays_completed_attempted', 'C/ATT'),
           ('passing', 'passing_yards', 'YDS'),
           ('passing', 'passing_percentage', 'PCT%'),
           ('passing', 'passing_touchdowns', 'TD'),
           ('passing', 'passing_plays_intercepted', 'INT'),

           ('rushing', 'player_display', 'RUSHING'),
           ('rushing', 'rushing_plays', 'CAR'),
           ('rushing', 'rushing_net_yards', 'YDS'),
           ('rushing', 'rushing_average_yards', 'AVG'),
           ('rushing', 'rushing_touchdowns', 'TD'),
           ('rushing', 'rushing_longest_yards', 'LG'),

           ('receiving', 'player_display', 'RECEIVING'),
           ('receiving', 'receiving_receptions', 'REC'),
           ('receiving', 'receiving_yards', 'YDS'),
           ('receiving', 'receiving_average_yards', 'AVG'),
           ('receiving', 'receiving_touchdowns', 'TD'),
           ('receiving', 'receiving_longest_yards', 'LG'),
           
           ('defense', 'player_display', 'TACKLES'),
           ('defense', 'defense_tackles_total', 'TKL'),
           ('defense', 'defense_solo_tackles', 'SOL'),
           ('defense', 'defense_assisted_tackles', 'AST'),
           ('defense', 'defense_sacks', 'SK'),
           ('defense', 'defense_interceptions', 'INT')   
    
    DECLARE @stats TABLE
    (
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (player_key, column_name, value)
    SELECT player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_football
     WHERE event_key = @eventKey AND team_key = @teamKey

    DECLARE @football TABLE
	(
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        -- passing --
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        passing_touchdowns        INT,
        passing_plays_intercepted INT,
        -- rushing --
        rushing_plays         INT,
        rushing_net_yards     INT,
        rushing_touchdowns    INT,
        rushing_longest_yards INT,
        -- receiving --
        receiving_receptions    INT,
        receiving_yards         INT,
        receiving_touchdowns    INT,
        receiving_longest_yards INT,
        -- defense --
		defense_solo_tackles     INT,
		defense_assisted_tackles INT,
		defense_sacks            VARCHAR(100),
		defense_interceptions    INT,
		-- team
        passing_net_yards       INT,
		total_first_downs       INT,
		fumbles_lost            INT,
		time_of_possession_secs VARCHAR(100)
	)

	INSERT INTO @football (player_key, passing_plays_completed, passing_plays_attempted, passing_yards,
	                       passing_touchdowns, passing_plays_intercepted,
                           rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                           receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,                           
                           defense_solo_tackles, defense_assisted_tackles, defense_sacks,defense_interceptions,
                           passing_net_yards, total_first_downs, fumbles_lost, time_of_possession_secs)
    SELECT p.player_key, ISNULL(passing_plays_completed, 0), ISNULL(passing_plays_attempted, 0), ISNULL(passing_yards, 0),
           ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0),
           ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_touchdowns, 0), ISNULL(rushing_longest_yards, 0),
           ISNULL(receiving_receptions, 0), ISNULL(receiving_yards, 0), ISNULL(receiving_touchdowns, 0), ISNULL(receiving_longest_yards, 0),                           
           ISNULL(defense_solo_tackles, 0), ISNULL(defense_assisted_tackles, 0), ISNULL(defense_sacks, 0), ISNULL(defense_interceptions, 0),
           ISNULL(passing_net_yards, 0), ISNULL(total_first_downs, 0), ISNULL(fumbles_lost, 0), ISNULL(time_of_possession_secs, 0)
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (passing_plays_completed, passing_plays_attempted, passing_yards,
                                               passing_touchdowns, passing_plays_intercepted,
                                               rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                                               receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,                           
                                               defense_solo_tackles, defense_assisted_tackles, defense_sacks,defense_interceptions,
                                               passing_net_yards, total_first_downs, fumbles_lost, time_of_possession_secs)) AS p

    -- calculations
    UPDATE t
       SET t.passing_net_yards = (SELECT SUM(p.passing_yards) FROM @football p)
      FROM @football t
     WHERE t.player_key = 'team' AND t.passing_net_yards = 0

    UPDATE t
       SET t.rushing_net_yards = (SELECT SUM(p.rushing_net_yards) FROM @football p)
      FROM @football t
     WHERE t.player_key = 'team' AND t.rushing_net_yards = 0

    UPDATE t
       SET t.total_first_downs = (SELECT COUNT(*)
                                    FROM dbo.SMG_Plays_Info i
                                   INNER JOIN dbo.SMG_Plays_NFL n
                                      ON n.event_key = i.event_key AND n.team_key = @teamKey AND
                                         n.sequence_number = i.sequence_number AND n.no_play = 'false'
                                   WHERE i.event_key = @eventKey AND i.play_type = 'play' AND i.[column] = 'down' AND i.value = '1')
      FROM @football t
     WHERE t.player_key = 'team' AND t.total_first_downs = 0

    UPDATE t
       SET t.time_of_possession_secs = (SELECT ((SUM(CAST(LEFT(time_of_possession, LEN(time_of_possession) - 3) AS INT)) * 60) + SUM(CAST(RIGHT(time_of_possession, 2) AS INT)))
                                          FROM dbo.USCP_football_drives
                                         WHERE event_key = @eventKey AND team_key = @teamKey)
      FROM @football t
     WHERE t.player_key = 'team' AND t.time_of_possession_secs = 0


    -- extract total
	DECLARE @total TABLE
	(
        id       INT IDENTITY(1, 1) PRIMARY KEY,
        category VARCHAR(100),
    	display  VARCHAR(100)
	)
	
	INSERT INTO @total (category, display)
    SELECT 'Total Yards', passing_net_yards + rushing_net_yards
	  FROM @football
	 WHERE player_key = 'team'
	 
	INSERT INTO @total (category, display)
	SELECT 'Passing', passing_net_yards
	  FROM @football
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Rushing', rushing_net_yards
	  FROM @football
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'First Downs', total_first_downs
	  FROM @football
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Turnovers', passing_plays_intercepted + fumbles_lost
	  FROM @football
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'Possession', CAST((time_of_possession_secs / 60) AS VARCHAR) + ':' +
                         CASE
                             WHEN time_of_possession_secs % 60 > 9 THEN CAST((time_of_possession_secs % 60) AS VARCHAR)
                             ELSE '0' + CAST((time_of_possession_secs % 60) AS VARCHAR)
                         END
	  FROM @football
	 WHERE player_key = 'team'

     
	UPDATE f
	   SET f.player_display = LEFT(s.first_name, 1) + '. ' + s.last_name
	  FROM @football AS f
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = f.player_key AND s.first_name <> 'TEAM'

    DELETE @football
     WHERE player_display IS NULL


    -- passing
    DECLARE @passing TABLE
    (
        player_display            VARCHAR(100),
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        passing_percentage        VARCHAR(100),
        passing_touchdowns        INT,
        passing_plays_intercepted INT
    )
	INSERT INTO @passing (player_display, passing_plays_completed, passing_plays_attempted, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted)
	SELECT player_display, passing_plays_completed, passing_plays_attempted, passing_yards,
	       CAST((100 * CAST(passing_plays_completed AS FLOAT) / passing_plays_attempted) AS DECIMAL(5,1)),
	       passing_touchdowns, passing_plays_intercepted
	  FROM @football
     WHERE player_key <> 'team' AND passing_plays_attempted > 0

	IF EXISTS(SELECT 1 FROM @passing)
	BEGIN
		INSERT INTO @passing (player_display, passing_plays_completed, passing_plays_attempted, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted)
		SELECT 'TOTAL', SUM(passing_plays_completed), SUM(passing_plays_attempted), SUM(passing_yards),
						CAST(100 * CAST(SUM(passing_plays_completed) AS FLOAT) / SUM(passing_plays_attempted) AS DECIMAL(5,1)),
						SUM(passing_touchdowns), SUM(passing_plays_intercepted)
		  FROM @passing
	END
	ELSE IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'passing'
	END


    -- rushing
    DECLARE @rushing TABLE
    (
        player_display        VARCHAR(100),
        rushing_plays         INT,
        rushing_net_yards     INT,
        rushing_average_yards VARCHAR(100),
        rushing_touchdowns    INT,
        rushing_longest_yards INT
    )
	INSERT INTO @rushing (player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards)
	SELECT player_display, rushing_plays, rushing_net_yards,
	       CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(4,1)),
	       rushing_touchdowns, rushing_longest_yards
	  FROM @football
     WHERE player_key <> 'team' AND rushing_plays > 0

	IF EXISTS(SELECT 1 FROM @rushing)
	BEGIN
		INSERT INTO @rushing (player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards)
		SELECT 'TOTAL', SUM(rushing_plays), SUM(rushing_net_yards),
		       CAST(CAST(SUM(rushing_net_yards) AS FLOAT) / SUM(rushing_plays) AS DECIMAL(4,1)),
		       SUM(rushing_touchdowns), MAX(rushing_longest_yards)
		  FROM @rushing
	END
	ELSE IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'rushing'
	END


    -- receiving
    DECLARE @receiving TABLE
    (
        player_display          VARCHAR(100),
        receiving_receptions    INT,
        receiving_yards         INT,
        receiving_average_yards VARCHAR(100),
        receiving_touchdowns    INT,
        receiving_longest_yards INT
    )
	INSERT INTO @receiving (player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards)
	SELECT player_display, receiving_receptions, receiving_yards,
	       CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(4,1)),
	       receiving_touchdowns, receiving_longest_yards
	  FROM @football
     WHERE player_key <> 'team' AND receiving_receptions > 0

	IF EXISTS(SELECT 1 FROM @receiving)
	BEGIN
		INSERT INTO @receiving (player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards)
		SELECT 'TOTAL', SUM(receiving_receptions), SUM(receiving_yards),
		       CAST(CAST(SUM(receiving_yards) AS FLOAT) / SUM(receiving_receptions) AS DECIMAL(4,1)),
		       SUM(receiving_touchdowns), MAX(receiving_longest_yards)
		  FROM @receiving
	END
	ELSE IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'receiving'
	END


    -- defense --
    DECLARE @defense TABLE
    (
        player_display           VARCHAR(100),
		defense_tackles_total    INT,
		defense_solo_tackles     INT,
		defense_assisted_tackles INT,
		defense_sacks            VARCHAR(100),
		defense_interceptions    INT
    )
	INSERT INTO @defense (player_display, defense_tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_interceptions)
	SELECT player_display, defense_solo_tackles + defense_assisted_tackles, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_interceptions
	  FROM @football
	 WHERE player_key <> 'team' AND defense_solo_tackles + defense_assisted_tackles + CAST(defense_sacks AS FLOAT) + defense_interceptions > 0

	IF EXISTS(SELECT 1 FROM @defense)
	BEGIN
		INSERT INTO @defense (player_display, defense_tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_interceptions)
		SELECT 'TOTAL', SUM(defense_tackles_total), SUM(defense_solo_tackles), SUM(defense_assisted_tackles), SUM(CAST(defense_sacks AS FLOAT)), SUM(defense_interceptions)
		  FROM @defense
	END
	ELSE IF (@eventKey IS NOT NULL)
	BEGIN
		DELETE FROM @columns WHERE table_name = 'defense'
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
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'passing'
                    ORDER BY passing_yards DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE player_display = 'TOTAL' AND t.table_name = 'passing'
                      FOR XML PATH('total'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'rushing'
                    ORDER BY rushing_net_yards DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE player_display = 'TOTAL' AND t.table_name = 'rushing'
                      FOR XML PATH('total'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'receiving'
                    ORDER BY receiving_yards DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE player_display = 'TOTAL' AND t.table_name = 'receiving'
                      FOR XML PATH('total'), TYPE
               ),
               (
                   SELECT player_display, defense_tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_interceptions
                     FROM @defense
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'defense'
                    ORDER BY defense_tackles_total DESC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, defense_tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_interceptions
                     FROM @defense
                    WHERE player_display = 'TOTAL' AND t.table_name = 'defense'
                      FOR XML PATH('total'), TYPE
               )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE
	),
	(
   	    SELECT category, display
		  FROM @total
		 ORDER BY id ASC
		   FOR XML PATH('total'), TYPE
	)
	FOR XML PATH(''), ROOT('root')
	
	SET NOCOUNT OFF;
END

GO
