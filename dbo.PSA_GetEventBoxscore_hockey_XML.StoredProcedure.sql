USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_hockey_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_hockey_XML] 
    @seasonKey INT,
    @eventKey VARCHAR(100),
    @teamKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/27/2014
-- Description: get event boxscore
-- Update: 10/03/2014 - John Lin - fix bug
--         10/21/2014 - John Lin - change text TEAM to TOTAL
--         11/07/2014 - ikenticus - updated TEAM conditionals to TOTAL
--		   11/18/2014 - ikenticus - converting save percentage from decimal to %
--         09/23/2015 - John Lin - SDI migration
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
    VALUES ('goaltending'), ('skaters')

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('goaltending', 'player_display', 'GOALTENDING'),
           ('goaltending', 'shots_against', 'SA'),
           ('goaltending', 'goals_against', 'GA'),
           ('goaltending', 'saves', 'SAVES'),
           ('goaltending', 'save-percentage', 'SV%'),

           ('skaters', 'player_display', 'SKATERS'),
           ('skaters', 'goals', 'G'),
           ('skaters', 'assists', 'A'),
           ('skaters', 'shots', 'SH'),
           ('skaters', 'penalty_minutes', 'PIM')

    DECLARE @stats TABLE
    (
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (player_key, column_name, value)
    SELECT player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_hockey
     WHERE event_key = @eventKey AND team_key = @teamKey

    DECLARE @hockey TABLE
	(
		player_key        VARCHAR(100),
	    player_display    VARCHAR(100),
        -- goaltending --
        shots_against     INT,
        goals_against     INT,
        [saves]           INT,
        [save-percentage] VARCHAR(100),
        -- skaters --
        goals            INT,
        assists          INT,
        shots            INT,
        penalty_minutes  INT,
        [time-on-ice]    VARCHAR(100),
        time_on_ice_secs INT,
		-- team
		goals_power_play INT,
		power_plays      INT
	)

	INSERT INTO @hockey (player_key,
	                     shots_against, goals_against,
                         goals, assists, shots, penalty_minutes, time_on_ice_secs,
                         goals_power_play, power_plays)
    SELECT p.player_key,
           ISNULL(shots_against, 0), ISNULL(goals_against, 0),
           ISNULL(goals, 0), ISNULL(assists, 0), ISNULL(shots, 0), ISNULL(penalty_minutes, 0), ISNULL(time_on_ice_secs, 0),
           ISNULL(goals_power_play, 0), ISNULL(power_plays, 0)
      FROM (SELECT player_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (shots_against, goals_against,
                                               goals, assists, shots, penalty_minutes, time_on_ice_secs,
                                               goals_power_play, power_plays)) AS p

    -- calculations
    UPDATE @hockey
       SET [saves] = (shots_against - goals_against),
           [time-on-ice] = CAST((CAST(time_on_ice_secs AS INT)/ 60) AS VARCHAR) + ':' +
                           CASE
                               WHEN CAST(time_on_ice_secs AS INT) % 60 > 9 THEN CAST((CAST(time_on_ice_secs AS INT) % 60) AS VARCHAR)
                               ELSE '0' + CAST((CAST(time_on_ice_secs AS INT) % 60) AS VARCHAR)
                           END

    UPDATE @hockey
       SET [save-percentage] = CAST(CAST((CAST([saves] AS FLOAT) / shots_against * 100) AS DECIMAL(5, 1)) AS VARCHAR)
     WHERE shots_against > 0

    -- extract out total
	DECLARE @total TABLE
	(
        id INT IDENTITY(1, 1) PRIMARY KEY,
        category VARCHAR(100),
    	display VARCHAR(100)
	)
	
	INSERT INTO @total (category, display)
    SELECT 'Shots On Goal', shots
	  FROM @hockey
	 WHERE player_key = 'team'
	 
	INSERT INTO @total (category, display)
    SELECT 'Power Plays', CAST(goals_power_play AS VARCHAR) + ' for ' + CAST(power_plays AS VARCHAR)
	  FROM @hockey
	 WHERE player_key = 'team'

	INSERT INTO @total (category, display)
    SELECT 'PIM', penalty_minutes
	  FROM @hockey
	 WHERE player_key = 'team'


    -- PLAYER
	UPDATE h
	   SET h.player_display = LEFT(s.first_name, 1) + '. ' + s.last_name
	  FROM @hockey AS h
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = h.player_key AND s.first_name <> 'TEAM'

    DELETE @hockey
     WHERE player_display IS NULL

    -- shots_on_goal
    DECLARE @goaltending TABLE
    (
        player_display    VARCHAR(100),
        shots_against     INT,
        goals_against     INT,
        [saves]           INT,
        [save-percentage] VARCHAR(100),
        [time-on-ice]     VARCHAR(100)
    )
	INSERT INTO @goaltending (player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice])
	SELECT player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
	  FROM @hockey
     WHERE shots_against > 0

	INSERT INTO @goaltending (player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice])
    SELECT 'TOTAL', SUM(shots_against), SUM(goals_against), SUM([saves]), '-', '-'
      FROM @goaltending

    -- skaters
    DECLARE @skaters TABLE
    (
        player_display  VARCHAR(100),
        goals           INT,
        assists         INT,
        shots           INT,
        penalty_minutes INT
    )
	INSERT INTO @skaters (player_display, goals, assists, shots, penalty_minutes)
	SELECT player_display, goals, assists, shots, penalty_minutes
	  FROM @hockey
     WHERE shots_against = 0

	INSERT INTO @skaters (player_display, goals, assists, shots, penalty_minutes)
    SELECT 'TOTAL', SUM(goals), SUM(assists), SUM(shots), SUM(penalty_minutes)
      FROM @skaters



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
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage]
                     FROM @goaltending
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'goaltending'
                    ORDER BY shots_against ASC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage]
                     FROM @goaltending
                    WHERE player_display = 'TOTAL' AND t.table_name = 'goaltending'
                      FOR XML PATH('total'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, shots, penalty_minutes
                     FROM @skaters
                    WHERE player_display <> 'TOTAL' AND t.table_name = 'skaters'
                    ORDER BY goals ASC, assists ASC, shots ASC
                      FOR XML PATH('rows'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, shots, penalty_minutes
                     FROM @skaters
                    WHERE player_display = 'TOTAL' AND t.table_name = 'skaters'
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
