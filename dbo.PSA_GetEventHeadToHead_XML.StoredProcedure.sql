USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventHeadToHead_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PSA_GetEventHeadToHead_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 06/27/2014
-- Description:	get head to head
-- Update:		09/11/2014 - ikenticus: updating MLS
-- 				09/19/2014 - ikenticus: adding EPL/Champions
--              09/22/2014 - John Lin - add NHL
-- 				10/07/2014 - ikenticus: commenting out possession, adding % to efficiencies
--				11/11/2014 - ikenticus - per SJ-824, converting mid-event efficiencies %
--				11/18/2014 - ikenticus - football turnovers = passes_interceptions + fumbles_lost (not committed)
--				12/09/2014 - ikenticus - fixing SJ-1039 discrepancies
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--              05/15/2015 - ikenticus: adjusting for world cup
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--              09/23/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END        

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
   
    SELECT TOP 1 @event_key = event_key, @away_key = away_team_key, @home_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@leagueName = 'mlb' OR @event_status = 'pre-event')
    BEGIN
		SELECT '' AS head_to_head
    	   FOR XML PATH(''), ROOT('root')
    
        RETURN
    END

	DECLARE @head2head TABLE
	(
		id          INT IDENTITY(1, 1) PRIMARY KEY,
		display     VARCHAR(100),
		away_value  VARCHAR(100),
		home_value  VARCHAR(100),
		column_name VARCHAR(100)
	)
   	DECLARE @stats TABLE
   	(
    	team_key    VARCHAR(100),
	    column_name VARCHAR(100),
		value       VARCHAR(100)
   	)

	IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
	BEGIN
	    INSERT INTO @stats (team_key, column_name, value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_soccer
	     WHERE event_key = @event_key AND player_key = 'team' AND
		       [column] IN ('possession-percentage', 'shots-total', 'shots-on-goal-total', 'offsides', 'fouls-committed', 'corner-kicks')

        IF EXISTS (SELECT 1 FROM @stats)
        BEGIN
    		INSERT INTO @head2head (display, column_name)
	    	VALUES --('Possession %', 'possession-percentage'), 
				   ('Goal Attempts', 'shots-total'), ('Shots On Goal', 'shots-on-goal-total'), 
                   ('Corner Kicks', 'corner-kicks'), ('Fouls', 'fouls-committed'), ('Offsides', 'offsides')

    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @stats tt
	    		ON tt.column_name = h2h.column_name AND tt.team_key = @away_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @stats tt
			    ON tt.column_name = h2h.column_name AND tt.team_key = @home_key

            UPDATE @head2head
			   SET away_value = 0
             WHERE away_value IS NULL

            UPDATE @head2head
			   SET home_value = 0
             WHERE home_value IS NULL
        END
	END
	IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
	BEGIN
	    INSERT INTO @stats (team_key, column_name, value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_basketball
	     WHERE event_key = @event_key AND player_key = 'team' AND
		       [column] IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage', 'assists-total',
			    			'rebounds-total', 'blocks-total', 'steals-total', 'turnovers-total', 'personal-fouls')

        IF EXISTS (SELECT 1 FROM @stats)
        BEGIN
    		INSERT INTO @head2head (display, column_name)
	    	VALUES ('Field Goal %', 'field-goals-percentage'), ('3PT Field Goal %', 'three-pointers-percentage'),
		    	   ('Free Throw %', 'free-throws-percentage'), ('Assists', 'assists-total'), ('Rebounds', 'rebounds-total'),
			       ('Blocks', 'blocks-total'), ('Steals', 'steals-total'), ('Turnovers', 'turnovers-total'), ('Fouls', 'personal-fouls')

    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @stats tt
	    		ON tt.column_name = h2h.column_name AND tt.team_key = @away_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @stats tt
			    ON tt.column_name = h2h.column_name AND tt.team_key = @home_key

            UPDATE @head2head
               SET away_value = CAST(ROUND(CAST(away_value AS FLOAT) * 100, 0) AS VARCHAR) + '%',
                   home_value = CAST(ROUND(CAST(home_value AS FLOAT) * 100, 0) AS VARCHAR) + '%'
             WHERE column_name IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage')
            
            DELETE @head2head
             WHERE away_value IS NULL OR home_value IS NULL
        END
    END
	IF (@leagueName IN ('ncaaf', 'nfl'))
	BEGIN	
	    INSERT INTO @stats(team_key, column_name, value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_football
	     WHERE event_key = @event_key AND player_key = 'team' AND
		       [column] IN ('first-downs-total', 'first-downs-pass', 'first-downs-run', 'first-downs-penalty',
			    			'conversions-third-down', 'conversions-third-down-attempts', 'conversions-third-down-percentage',
                            'conversions-fourth-down', 'conversions-fourth-down-attempts', 'conversions-fourth-down-percentage',
                            'offensive-plays-yards', 'passes-average-yards-per', 'rushing-average-yards-per', 'receptions-average-yards-per',
                            'passes-yards-gross', 'passes-yards-net', 'passes-completions', 'passes-attempts', 'passes-average-yards-per',
                            'sacks-against-total', 'sacks-against-yards', 'rushes-yards', 'rushes-attempts', 'rushing-average-yards-per',
                            'penalties-total', 'penalty-yards', 'fumbles-committed', 'fumbles-lost', 'passes-interceptions', 'time-of-possession')

        IF EXISTS (SELECT 1 FROM @stats)
        BEGIN
            DECLARE @football TABLE
            (
		        team_key                             VARCHAR(100),
	            [conversions-third-down]             VARCHAR(100),
	            [conversions-third-down-attempts]    VARCHAR(100),
	            [conversions-third-down-percentage]  VARCHAR(100),
	            [conversions-fourth-down]            VARCHAR(100),
	            [conversions-fourth-down-attempts]   VARCHAR(100),
	            [conversions-fourth-down-percentage] VARCHAR(100),
	            [passes-average-yards-per]           VARCHAR(100),
                [rushing-average-yards-per]          VARCHAR(100),
                [passes-completions]                 VARCHAR(100),
                [passes-attempts]                    VARCHAR(100),
                [rushes-attempts]                    VARCHAR(100),
                [offensive-plays-yards]              VARCHAR(100),
                [sacks-against-total]                VARCHAR(100),
                [sacks-against-yards]                VARCHAR(100),
                [fumbles-committed]                  VARCHAR(100),
                [fumbles-lost]                       VARCHAR(100),
                [passes-interceptions]               VARCHAR(100),
                [time-of-possession]                 VARCHAR(100)
	        )
	        INSERT INTO @football (team_key, [conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	                               [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	                               [passes-average-yards-per], [rushing-average-yards-per], [passes-completions], [passes-attempts], [rushes-attempts],
                                   [sacks-against-total], [sacks-against-yards], [fumbles-committed], [fumbles-lost], [passes-interceptions],
                                   [time-of-possession], [offensive-plays-yards])
            SELECT p.team_key, [conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	               [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	               [passes-average-yards-per], [rushing-average-yards-per], [passes-completions], [passes-attempts], [rushes-attempts],
                   [sacks-against-total], [sacks-against-yards], [fumbles-committed], [fumbles-lost], [passes-interceptions],
                   [time-of-possession], [offensive-plays-yards]
              FROM (SELECT team_key, column_name, value FROM @stats) AS s
             PIVOT (MAX(s.value) FOR s.column_name IN ([conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	                                                   [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	                                                   [passes-average-yards-per], [rushing-average-yards-per], [passes-completions], [passes-attempts], [rushes-attempts],
                                                       [sacks-against-total], [sacks-against-yards], [fumbles-committed], [fumbles-lost], [passes-interceptions],
                                                       [time-of-possession], [offensive-plays-yards])) AS p

			UPDATE @football
			   SET [conversions-third-down-percentage] = CAST(100 * CAST([conversions-third-down-percentage] AS FLOAT) AS INT)
			 WHERE CAST([conversions-third-down-percentage] AS FLOAT) < 10.00

			UPDATE @football
			   SET [conversions-fourth-down-percentage] = CAST(100 * CAST([conversions-fourth-down-percentage] AS FLOAT) AS INT)
			 WHERE CAST([conversions-fourth-down-percentage] AS FLOAT) < 10.00

			-- SJ-1069 Discrepancies:
			--		Passing: passes-yards-gross vs passes-yards-net (ESPN)
			--		Yards per completion: receptions-average-yards-per
			--		   vs Yards per pass: passes-average-yards-per
			--		Yards per offensive play: Total Yards / Total Plays (Total Plays = Passes Attempts + Rushes Attempts + Sacks)
			--									NOT passes-average-yards-per + rushing-average-yards-per

    		INSERT INTO @head2head (display, column_name)
	    	VALUES ('1st downs', 'first-downs-total'), ('Passing 1st downs', 'first-downs-pass'), ('Rushing 1st downs', 'first-downs-run'),
	    	       ('1st downs from penalties', 'first-downs-penalty'), ('3rd down efficiency', ''), ('4th down efficiency', ''),
	    	       ('Total yards', 'offensive-plays-yards'), ('Yards per offensive play', ''), ('Passing', 'passes-yards-net'),
	    	       ('Comp - Att', ''), ('Yards per pass', 'passes-average-yards-per'), ('Sacked (number - yards)', ''),
	    	       ('Rushing', 'rushes-yards'), ('Rushing carries', 'rushes-attempts'), ('Yards per carry', 'rushing-average-yards-per'),
	    	       ('Turnovers', ''), ('Fumbles - Fumbles lost', ''), ('Interception thrown', 'passes-interceptions')

			IF NOT EXISTS (SELECT 1 FROM @stats WHERE column_name = 'passes-yards-net')
			BEGIN
				UPDATE @head2head
				   SET column_name = 'passes-yards-gross'
				 WHERE column_name = 'passes-yards-net'
			END

            IF EXISTS (SELECT 1 FROM @football WHERE [time-of-possession] IS NOT NULL)
            BEGIN
                INSERT INTO @head2head (display, column_name)
                VALUES ('Possession', 'time-of-possession')
            END
	    		    	
    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @stats tt
	    		ON tt.column_name = h2h.column_name AND tt.team_key = @away_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @stats tt
			    ON tt.column_name = h2h.column_name AND tt.team_key = @home_key

            UPDATE @head2head
               SET away_value = (SELECT [conversions-third-down] + '-' + [conversions-third-down-attempts] + ' (' + [conversions-third-down-percentage] + '%)'
                                   FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [conversions-third-down] + '-' + [conversions-third-down-attempts] + ' (' + [conversions-third-down-percentage] + '%)'
                                   FROM @football WHERE team_key = @home_key)
             WHERE display = '3rd down efficiency'

            UPDATE @head2head
               SET away_value = (SELECT [conversions-fourth-down] + '-' + [conversions-fourth-down-attempts] + ' (' + [conversions-fourth-down-percentage] + '%)'
                                   FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [conversions-fourth-down] + '-' + [conversions-fourth-down-attempts] + ' (' + [conversions-fourth-down-percentage] + '%)'
                                   FROM @football WHERE team_key = @home_key)
             WHERE display = '4th down efficiency'

            UPDATE @head2head
               SET away_value = (SELECT CAST(
											CAST([offensive-plays-yards] AS FLOAT) / (
												CAST([passes-attempts] AS INT) + CAST([rushes-attempts] AS INT) + CAST([sacks-against-total] AS INT)
											)
										AS DECIMAL(4,1))
                                   FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT CAST(
											CAST([offensive-plays-yards] AS FLOAT) / (
												CAST([passes-attempts] AS INT) + CAST([rushes-attempts] AS INT) + CAST([sacks-against-total] AS INT)
											)
										AS DECIMAL(4,1))
                                   FROM @football WHERE team_key = @home_key)
             WHERE display = 'Yards per offensive play'

            UPDATE @head2head
               SET away_value = (SELECT [passes-completions] + '-' + [passes-attempts] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [passes-completions] + '-' + [passes-attempts] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Comp - Att'
            
            UPDATE @head2head
               SET away_value = (SELECT [sacks-against-total] + '-' + [sacks-against-yards] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [sacks-against-total] + '-' + [sacks-against-yards] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Sacked (number - yards)'

            UPDATE @head2head
               SET away_value = (SELECT CAST([passes-interceptions] AS INT) + CAST([fumbles-lost] AS INT)
                                   FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT CAST([passes-interceptions] AS INT) + CAST([fumbles-lost] AS INT)
                                   FROM @football WHERE team_key = @home_key)
             WHERE display = 'Turnovers'

            UPDATE @head2head
               SET away_value = (SELECT [fumbles-committed] + '-' + [fumbles-lost] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [fumbles-committed] + '-' + [fumbles-lost] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Fumbles - Fumbles lost'

            DELETE @head2head
             WHERE away_value IS NULL OR home_value IS NULL
        END
	END
	IF (@leagueName = 'nhl')
	BEGIN
	    INSERT INTO @stats (team_key, column_name, value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_hockey
	     WHERE event_key = @event_key AND player_key = 'team'

        IF EXISTS (SELECT 1 FROM @stats)
        BEGIN
    		INSERT INTO @head2head (display, column_name)
	    	VALUES ('Shots on Goal', 'shots'), ('Power Plays', 'power_plays'), ('Faceoffs Won', 'faceoff_total_wins'), ('Faceoffs Lost', 'faceoff_total_losses'),
	    	       ('Hits', 'player_hits'), ('PIM', 'penalty_minutes')

    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @stats tt
	    		ON tt.column_name = h2h.column_name AND tt.team_key = @away_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @stats tt
			    ON tt.column_name = h2h.column_name AND tt.team_key = @home_key
            
            DELETE @head2head
             WHERE away_value IS NULL OR home_value IS NULL
        END
	END

 
	SELECT
	(
		SELECT display, away_value, home_value
		  FROM @head2head
		 ORDER BY id ASC
		   FOR XML PATH('head_to_head'), TYPE
	)
	FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
