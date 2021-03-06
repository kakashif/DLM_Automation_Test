USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventIdsSolo_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventIdsSolo_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100),
    @year INT,
    @month INT,
    @day INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/16/2014
-- Description: get event ids for solo
-- Update:		07/23/2014 - ikenticus - adding brief_display for CMS dropdown
-- Update:		10/02/2014 - ikenticus - adding MMA
--				03/26/2015 - ikenticus - adding motor
--				07/16/2015 - ikenticus - using league_key function
--				09/18/2015 - ikenticus - limiting mapping to 'league' value_type
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'mma', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @date DATE = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    DECLARE @events TABLE (
        season_key INT,
        event_key VARCHAR(100),
        event_name VARCHAR(100),
        match_key VARCHAR(100),
        -- extra        
        match_id VARCHAR(100),
        event_id VARCHAR(100),
		league_id VARCHAR(100),
		league_key VARCHAR(100),
        brief_display VARCHAR(100),
        brief_endpoint VARCHAR(100),
		start_date_time DATETIME
    )    

	IF (@leagueId IS NULL OR @leagueID = '')
	BEGIN
		DECLARE @league_source VARCHAR(100)

		SELECT TOP 1 @league_source = filter
		  FROM dbo.SMG_Default_Dates
		 WHERE page = 'source' AND league_key = @leagueName

		INSERT INTO @events (league_key, season_key, event_key, event_name, start_date_time)
		SELECT l.league_key, l.season_key, event_key, event_name, start_date_time
		  FROM SportsDB.dbo.SMG_Solo_Leagues AS l
		 INNER JOIN SportsDB.dbo.SMG_Solo_Events AS e ON e.league_key = l.league_key AND e.season_key = l.season_key
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON value_from = l.league_key AND source = @league_source
		 WHERE (start_date_time BETWEEN @date AND DATEADD(DAY, 1, @date) OR @date BETWEEN start_date_time AND end_date_time)
		   AND league_name = @leagueName AND m.value_type = 'league'
	END
	ELSE
	BEGIN
		INSERT INTO @events (league_key, season_key, event_key, event_name, start_date_time)
		SELECT league_key, season_key, event_key, event_name, start_date_time
		  FROM dbo.SMG_Solo_Events
		 WHERE (start_date_time BETWEEN @date AND DATEADD(DAY, 1, @date) OR @date BETWEEN start_date_time AND end_date_time)
		   AND league_key = @league_key

	END

	IF (@leagueName = 'tennis')
	BEGIN
		DECLARE @results TABLE  (
			league_key VARCHAR(100),
			season_key INT,
			event_key VARCHAR(100),
			event_name VARCHAR(100),
			player_name VARCHAR(100),
			[round] VARCHAR(100),
			[column] VARCHAR(100),
			value VARCHAR(100)
		)    

		INSERT INTO @results (league_key, season_key, event_key, event_name, player_name, [round], [column], value)
		SELECT e.league_key, e.season_key, e.event_key, e.event_name, player_name, [round], [column], value
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Solo_Results AS r ON e.event_key = r.event_key
		 WHERE r.[column] IN ('match-event-key', 'match-event-date')

		DECLARE @matches TABLE (
			league_key VARCHAR(100),
			season_key INT,
			event_key VARCHAR(100),
			event_name VARCHAR(100),
			player_name VARCHAR(100),
			[round] VARCHAR(100),
			[match-event-date] DATETIME,
			[match-event-key] VARCHAR(100),
			priority INT
		)

		INSERT INTO @matches (league_key, season_key, event_key, event_name, player_name, [round], [match-event-date], [match-event-key], priority)
		SELECT league_key, season_key, event_key, event_name, player_name, [round], [match-event-date], [match-event-key],
			   RANK() OVER (PARTITION BY [match-event-key] ORDER BY player_name)
		  FROM (SELECT league_key, season_key, event_key, event_name, player_name, [round], [column], value FROM @results) AS r
		 PIVOT (MAX(r.value) FOR r.[column] IN ([match-event-date], [match-event-key])) AS p
		 WHERE [match-event-date] BETWEEN @date AND DATEADD(DAY, 1, @date)

		INSERT INTO @events (league_key, season_key, event_key, match_key, start_date_time, event_name, brief_display)
		SELECT m1.league_key, m1.season_key, m1.event_key, m1.[match-event-key], m1.[match-event-date], m1.event_name,
			   m1.event_name + ' ' + m1.[round] + ' (' + m1.player_name + ' vs ' + m2.player_name + ')'
		  FROM @matches AS m1
		 INNER JOIN @matches AS m2 ON m2.[match-event-key] = m1.[match-event-key] AND m2.player_name <> m1.player_name
		 WHERE m1.priority = 1 AND m2.priority = 2
	END

    -- endpoint
    UPDATE e
       SET e.league_id = l.league_id
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Solo_Leagues AS l ON l.league_key = e.league_key AND l.season_key = e.season_key
	 
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    UPDATE @events
       SET match_id = dbo.SMG_fnEventId(match_key)

    UPDATE @events
       SET brief_endpoint = '/Event.svc/brief/' + @leagueName + '/' + league_id + '/' + CAST(season_key AS VARCHAR) + '/' + event_id
	 WHERE brief_endpoint IS NULL

    UPDATE @events
       SET brief_endpoint = brief_endpoint + '/' + match_id
	 WHERE match_id IS NOT NULL

    UPDATE @events
       SET brief_display = event_name + ' (' + league_id + ')'
	 WHERE brief_display IS NULL


	IF (@leagueName = 'mma')
	BEGIN
		UPDATE @events
		   SET brief_endpoint = '/Event.svc/brief/' + @leagueName + '/' + CAST(season_key AS VARCHAR) + '/' + event_id
	END

     
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT (
               SELECT 'true' AS 'json:Array',
                      event_name, brief_display, brief_endpoint
                 FROM @events
                ORDER BY start_date_time ASC
                  FOR XML RAW('events'), TYPE
           )
       FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
