USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventTabs_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventTabs_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	07/10/2014
-- Description:	get addional event detail by event status
-- Update:		07/17/2014 - John Lin - update matchup logic
--				09/19/2014 - ikenticus: adding EPL/Champions
--              10/16/2014 - John Lin - nhl render plays and team stats when post event
--              10/22/2014 - John Lin - render link only if data
--				11/14/2014 - ikenticus: adding missing EPL/Champions tabs
--				11/20/2014 - ikenticus: SJ-965, fixing incorrect EPL/Champions tabs
--              11/25/2014 - John Lin - check each team key
--				11/26/2014 - ikenticus - delete tab when display is null
--              12/17/2014 - John Lin - use AWAY/HOME as abbr if team has record but no abbr
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--				05/15/2015 - ikenticus: adding world cup inclusions
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
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
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)

      
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    SELECT @away_abbr = team_abbreviation
      FROM dbo.SMG_Teams 
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

    SELECT @home_abbr = team_abbreviation
      FROM dbo.SMG_Teams 
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key


    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS tabs
           FOR XML PATH(''), ROOT('root')

        RETURN
    END



    DECLARE @tabs TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        page_endpoint VARCHAR(100)
    )
    INSERT INTO @tabs (display, page_endpoint)
    VALUES ('Matchup', '/Event.svc/matchup/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR))
    
    IF (@leagueName = 'mlb')
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.SMG_Plays_MLB WHERE event_key = @event_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES ('Plays', '/Event.svc/plays/mlb/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR))
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_baseball WHERE event_key = @event_key AND team_key = @away_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@away_abbr + ' ' + 'Stats', '/Event.svc/boxscore/mlb/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/away')
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_baseball WHERE event_key = @event_key AND team_key = @home_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@home_abbr + ' ' + 'Stats', '/Event.svc/boxscore/mlb/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/home')
        END
    END
    ElSE IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
    BEGIN
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_soccer WHERE event_key = @event_key AND team_key = @away_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@away_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/away')
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_soccer WHERE event_key = @event_key AND team_key = @home_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@home_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/home')
        END
    END
    ElSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_basketball WHERE event_key = @event_key AND team_key = @away_key)
        BEGIN
            IF (@leagueName = 'ncaab' AND @away_abbr IS NULL)
            BEGIN
                SET @away_abbr = 'AWAY'
            END
            
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@away_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/away')
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_basketball WHERE event_key = @event_key AND team_key = @home_key)
        BEGIN
            IF (@leagueName = 'ncaab' AND @away_abbr IS NULL)
            BEGIN
                SET @away_abbr = 'HOME'
            END

            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@home_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/home')
        END
    END    
    ElSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.SMG_Plays_NFL WHERE event_key = @event_key)
        BEGIN
            IF (@leagueName = 'ncaaf' AND @away_abbr IS NULL)
            BEGIN
                SET @away_abbr = 'AWAY'
            END

            INSERT INTO @tabs (display, page_endpoint)
            VALUES ('Plays', '/Event.svc/plays/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR))
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_football WHERE event_key = @event_key AND team_key = @away_key)
        BEGIN
            IF (@leagueName = 'ncaaf' AND @away_abbr IS NULL)
            BEGIN
                SET @away_abbr = 'HOME'
            END

            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@away_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/away')
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_football WHERE event_key = @event_key AND team_key = @home_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@home_abbr + ' ' + 'Stats', '/Event.svc/boxscore/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/home')
        END
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.SMG_Plays_NHL WHERE event_key = @event_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES ('Plays', '/Event.svc/plays/nhl/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR))
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_hockey WHERE event_key = @event_key AND team_key = @away_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@away_abbr + ' ' + 'Stats', '/Event.svc/boxscore/nhl/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/away')
        END
        IF EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Events_hockey WHERE event_key = @event_key AND team_key = @home_key)
        BEGIN
            INSERT INTO @tabs (display, page_endpoint)
            VALUES (@home_abbr + ' ' + 'Stats', '/Event.svc/boxscore/nhl/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/home')
        END
    END

        
	DELETE
	  FROM @tabs
	 WHERE display IS NULL
      
    
    SELECT
    (
        SELECT display, page_endpoint
          FROM @tabs
         ORDER BY id ASC
           FOR XML RAW('tabs'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
