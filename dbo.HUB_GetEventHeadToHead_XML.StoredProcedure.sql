USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventHeadToHead_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventHeadToHead_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 07/29/2014
-- Description:	get head to head
-- Update: 09/09/2014 - John Lin - add % sign
--         07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
    
    SELECT TOP 1 @event_key = event_key, @away_key = away_team_key, @home_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 

	DECLARE @head2head TABLE
	(
		id          INT IDENTITY(1, 1) PRIMARY KEY,
		display     VARCHAR(100),
		away_value  VARCHAR(100),
		home_value  VARCHAR(100),
		column_name VARCHAR(100),
		parent      VARCHAR(100)
	)
   	DECLARE @stats TABLE
   	(
    	team_key    VARCHAR(100),
	    column_name VARCHAR(100),
		value       VARCHAR(100)
   	)
/*
	IF (@leagueName = 'mls')
	BEGIN
	    INSERT INTO @team_totals (team_key, [column], value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_basketball
	     WHERE event_key = @event_key AND player_key = 'team' AND
		       [column] IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage', 'assists-total',
			    			'rebounds-total', 'blocks-total', 'steals-total', 'turnovers-total', 'personal-fouls')

        IF EXISTS (SELECT 1 FROM @team_totals)
        BEGIN
    		INSERT INTO @head2head (display, column_name)
	    	VALUES ('Field Goal %', 'field-goals-percentage'), ('3PT Field Goal %', 'three-pointers-percentage'),
		    	   ('Free Throw %', 'free-throws-percentage'), ('Assists', 'assists-total'), ('Rebounds', 'rebounds-total'),
			       ('Blocks', 'blocks-total'), ('Steals', 'steals-total'), ('Turnovers', 'turnovers-total'), ('Fouls', 'personal-fouls')

    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @team_totals tt
	    		ON tt.[column] = h2h.column_name AND tt.team_key = @away_team_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @team_totals tt
			    ON tt.[column] = h2h.column_name AND tt.team_key = @home_team_key

            UPDATE @head2head
               SET away_value = CAST(away_value AS FLOAT) * 100, home_value = CAST(home_value AS FLOAT) * 100
             WHERE column_name IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage')
            
            DELETE @head2head
             WHERE away_value IS NULL OR home_value IS NULL
        END
	END
*/	
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
                            'offensive-plays-yards', 'offensive-plays-average-yards-per',
                            'passes-yards-gross', 'passes-completions', 'passes-attempts', 'passes-average-yards-per',
                            'sacks-against-total', 'sacks-against-yards',                             
                            'rushes-yards', 'rushes-attempts', 'rushing-average-yards-per',
                            'penalties-total', 'penalty-yards',
                            'interceptions-total', 'fumbles-committed', 'fumbles-lost',
                            'time-of-possession')


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
	            [offensive-plays-average-yards-per]  VARCHAR(100),
                [passes-completions]                 VARCHAR(100),
                [passes-attempts]                    VARCHAR(100),	            
                [sacks-against-total]                VARCHAR(100),
                [sacks-against-yards]                VARCHAR(100),
                [penalties-total]                    VARCHAR(100),
                [penalty-yards]                      VARCHAR(100),
                [interceptions-total]                VARCHAR(100),
                [fumbles-committed]                  VARCHAR(100),
                [fumbles-lost]                       VARCHAR(100),
                [time-of-possession]                 VARCHAR(100)
	        )
	        INSERT INTO @football (team_key, [conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	                               [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	                               [passes-completions], [passes-attempts], [sacks-against-total], [sacks-against-yards], [penalties-total],
	                               [penalty-yards], [fumbles-committed], [fumbles-lost], [interceptions-total], [time-of-possession])
            SELECT p.team_key, [conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	               [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	               [passes-completions], [passes-attempts], [sacks-against-total], [sacks-against-yards], [penalties-total],
	               [penalty-yards], [fumbles-committed], [fumbles-lost], [interceptions-total], [time-of-possession]
              FROM (SELECT team_key, column_name, value FROM @stats) AS s
             PIVOT (MAX(s.value) FOR s.column_name IN ([conversions-third-down], [conversions-third-down-attempts], [conversions-third-down-percentage],
	                                                   [conversions-fourth-down], [conversions-fourth-down-attempts], [conversions-fourth-down-percentage],
	                                                   [passes-completions], [passes-attempts], [sacks-against-total], [sacks-against-yards], [penalties-total],
	                                                   [penalty-yards], [fumbles-committed], [fumbles-lost], [interceptions-total], [time-of-possession])) AS p

    		INSERT INTO @head2head (display, column_name, parent)
	    	VALUES ('1st downs', 'first-downs-total', 1), ('Passing 1st downs', 'first-downs-pass', 0), ('Rushing 1st downs', 'first-downs-run', 0),
	    	       ('1st downs from penalties', 'first-downs-penalty', 0), ('3rd down efficiency', '', 0), ('4th down efficiency', '', 0),
	    	       ('Total yards', 'offensive-plays-yards', 1)
	    	       
            IF EXISTS (SELECT 1 FROM @football WHERE [offensive-plays-average-yards-per] IS NOT NULL)
            BEGIN
                INSERT INTO @head2head (display, column_name, parent)
                VALUES ('Yards Per Offensive Play', 'offensive_plays_average_yards_per', 0)
            END
	    	       
    		INSERT INTO @head2head (display, column_name, parent)
	    	VALUES ('Passing', 'passes-yards-gross', 1), ('Comp - Att', '', 0), ('Yards per completion', 'passes-average-yards-per', 0),
	    	       ('Sacked (number - yards)', '', 0), ('Rushing', 'rushes-yards', 1), ('Rushing carries', 'rushes-attempts', 0),
	    	       ('Yards per carry', 'rushing-average-yards-per', 0), ('Penalties - Yards', '', 1), ('Turnovers', '', 1),
	    	       ('Fumbles - Fumbles lost', '', 0), ('Interception thrown', 'interceptions-total', 0)

            IF EXISTS (SELECT 1 FROM @football WHERE [time-of-possession] IS NOT NULL)
            BEGIN
                INSERT INTO @head2head (display, column_name, parent)
                VALUES ('Possession', 'time-of-possession', 1)
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
               SET away_value = (SELECT [passes-completions] + '-' + [passes-attempts] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [passes-completions] + '-' + [passes-attempts] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Comp - Att'
            
            UPDATE @head2head
               SET away_value = (SELECT [sacks-against-total] + '-' + [sacks-against-yards] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [sacks-against-total] + '-' + [sacks-against-yards] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Sacked (number - yards)'

            UPDATE @head2head
               SET away_value = (SELECT [penalties-total] + '-' + [penalty-yards] FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT [penalties-total] + '-' + [penalty-yards] FROM @football WHERE team_key = @home_key)
             WHERE display = 'Penalties - Yards'

            UPDATE @head2head
               SET away_value = (SELECT CAST([interceptions-total] AS INT) + CAST([fumbles-committed] AS INT)
                                   FROM @football WHERE team_key = @away_key),
                   home_value = (SELECT CAST([interceptions-total] AS INT) + CAST([fumbles-committed] AS INT)
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
/*
	IF (@leagueName = 'nhl')
	BEGIN
	    INSERT INTO @team_totals (team_key, [column], value)
   		SELECT team_key, [column], value
    	  FROM SportsEditDB.dbo.SMG_Events_basketball
	     WHERE event_key = @event_key AND player_key = 'team' AND
		       [column] IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage', 'assists-total',
			    			'rebounds-total', 'blocks-total', 'steals-total', 'turnovers-total', 'personal-fouls')

        IF EXISTS (SELECT 1 FROM @team_totals)
        BEGIN
    		INSERT INTO @head2head (display, column_name)
	    	VALUES ('Field Goal %', 'field-goals-percentage'), ('3PT Field Goal %', 'three-pointers-percentage'),
		    	   ('Free Throw %', 'free-throws-percentage'), ('Assists', 'assists-total'), ('Rebounds', 'rebounds-total'),
			       ('Blocks', 'blocks-total'), ('Steals', 'steals-total'), ('Turnovers', 'turnovers-total'), ('Fouls', 'personal-fouls')

    		UPDATE h2h
	     	   SET h2h.away_value = tt.value
		      FROM @head2head h2h
    		 INNER JOIN @team_totals tt
	    		ON tt.[column] = h2h.column_name AND tt.team_key = @away_team_key

		    UPDATE h2h
		       SET h2h.home_value = tt.value
		      FROM @head2head h2h
		     INNER JOIN @team_totals tt
			    ON tt.[column] = h2h.column_name AND tt.team_key = @home_team_key

            UPDATE @head2head
               SET away_value = CAST(away_value AS FLOAT) * 100, home_value = CAST(home_value AS FLOAT) * 100
             WHERE column_name IN ('field-goals-percentage', 'three-pointers-percentage', 'free-throws-percentage')
            
            DELETE @head2head
             WHERE away_value IS NULL OR home_value IS NULL
        END
	END
*/
 
	SELECT
	(
		SELECT display, away_value, home_value, parent
		  FROM @head2head
		 ORDER BY id ASC
		   FOR XML PATH('head_to_head'), TYPE
	)
	FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
