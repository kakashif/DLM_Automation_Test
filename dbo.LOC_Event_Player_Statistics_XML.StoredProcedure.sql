USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Player_Statistics_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Player_Statistics_XML] 
    @leagueName VARCHAR(100),
    @eventId INT,
    @teamSlug VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 05/12/2015
-- Description: get event player statistics for USCP
-- Update: 06/23/2015 - John Lin - STATS migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    IF (@leagueName IN ('nba', 'nfl', 'wnba', 'ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        EXEC dbo.LOC_Event_Player_Statistics_new_XML @leagueName, @eventId, @teamSlug
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @event_key VARCHAR(100)
    DECLARE @date_time VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_score INT
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_score INT
    -- extra
    DECLARE @dt DATETIME
    DECLARE @team_key VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @event_key = event_key, @dt = start_date_time_EST, @game_status = game_status,
           @away_key = away_team_key, @home_key = home_team_key, @away_score = away_team_score, @home_score = home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
     
    SET @date_time = CAST(DATEPART(MONTH, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(DAY, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(YEAR, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) > 12 THEN CAST(DATEPART(HOUR, @dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, @dt) AS VARCHAR) END + ':' +
                     CASE WHEN DATEPART(MINUTE, @dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) < 12 THEN 'AM' ELSE 'PM' END

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

    -- All-Stars
    IF (@leagueName = 'mlb')
    BEGIN
        IF (@teamSlug = 'al')
        BEGIN
            SET @team_key = '321'
        END
        
        IF (@teamSlug = 'nl')
        BEGIN
            SET @team_key = '322'
        END
    END
     
    DECLARE @stats TABLE
    (
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (player_key, [column], value)
    SELECT player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_baseball
     WHERE event_key = @event_key AND team_key = @team_key AND player_key <> 'team'

	DECLARE @baseball TABLE
	(
		player_key VARCHAR(100),
	    name VARCHAR(100),	    
		[position-event] VARCHAR(100),
		-- pitching		
		[innings-pitched] VARCHAR(100),
		[number-of-pitches] INT,		
		[pitching-hits] INT,
		[runs-allowed] INT,	
		[earned-runs] INT,
		[pitching-bases-on-balls] INT,
		[pitching-strikeouts] INT,
		-- batting
        [at-bats] INT,
        [hits] INT,
        [runs-scored] INT,
        [rbi] INT,
        [home-runs] INT,
        [strikeouts] INT,
        -- extra
        [lineup-slot] INT,
        [lineup-slot-sequence] INT
	)	
    INSERT INTO @baseball (player_key, [position-event],
                           [innings-pitched], [number-of-pitches], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts],
                           [at-bats], [hits], [runs-scored], [rbi], [home-runs], [strikeouts],
                           [lineup-slot], [lineup-slot-sequence])
    SELECT p.player_key, [position-event],
           [innings-pitched], [number-of-pitches], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts],
           [at-bats], [hits], [runs-scored], [rbi], [home-runs], [strikeouts],
           [lineup-slot], [lineup-slot-sequence]
      FROM (SELECT player_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([position-event],
                                            [innings-pitched], [number-of-pitches], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts],
                                            [at-bats], [hits], [runs-scored], [rbi], [home-runs], [strikeouts],
                                            [lineup-slot], [lineup-slot-sequence])) AS p

    UPDATE @baseball
	   SET [position-event] = CASE
	                              WHEN [position-event] = '1' THEN 'P'
	                              WHEN [position-event] = '2' THEN 'C'
  	                              WHEN [position-event] = '3' THEN '1B'
	                              WHEN [position-event] = '4' THEN '2B'
	                              WHEN [position-event] = '5' THEN '3B'
	                              WHEN [position-event] = '6' THEN 'SS'
	                              WHEN [position-event] = '7' THEN 'LF'
	                              WHEN [position-event] = '8' THEN 'CF'
	                              WHEN [position-event] = '9' THEN 'RF'
	                              WHEN [position-event] = 'D' THEN 'DH'
	                              WHEN [position-event] = 'P' THEN 'PH'
	                              ELSE [position-event]
	                          END
	WHERE [position-event] IS NOT NULL

	UPDATE b
	   SET b.name = sp.first_name + ' ' + sp.last_name
	  FROM @baseball b
	 INNER JOIN dbo.SMG_Players sp
		ON sp.player_key = b.player_key

	

    SELECT
	(
		SELECT @away_key AS away_key, @home_key AS home_key, @away_score AS away_score, @home_score AS home_score,
               @date_time AS date_time, @game_status AS game_status,
		       (
                   SELECT name, [position-event], [innings-pitched], [number-of-pitches], [pitching-hits],
		                  [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts]
                     FROM @baseball
                    WHERE [innings-pitched] IS NOT NULL AND [innings-pitched] <> '0'
                    ORDER BY CAST([innings-pitched] AS FLOAT) DESC
                      FOR XML PATH('pitching'), TYPE
               ),
               (
                   SELECT name, [position-event], [at-bats], [hits], [runs-scored], [rbi], [home-runs], [strikeouts]
                     FROM @baseball
                    WHERE [at-bats] IS NOT NULL AND [at-bats] > 0 OR
                          [runs-scored] IS NOT NULL AND [runs-scored] > 0 OR
                          [hits] IS NOT NULL AND [hits] > 0 OR
                          [rbi] IS NOT NULL AND [rbi] > 0
                    ORDER BY [lineup-slot] ASC, [lineup-slot-sequence] ASC
                      FOR XML PATH('batting'), TYPE
               )
		   FOR XML PATH('players'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
