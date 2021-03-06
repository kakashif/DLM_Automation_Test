USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSolo_MMA_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSolo_MMA_XML] 
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 10/02/2014
-- Description: get event brief for MMA
-- Update:		10/09/2014 - ikenticus: adjusting to new leagues from ingestor
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--              01/22/2015 - John Lin - add UTC
--				03/04/2015 - ikenticus - fixing other event_status
--				06/30/2015 - ikenticus - using MMA event id as event_key
--				10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

	DECLARE @league_name VARCHAR(100) = 'mma'
    DECLARE @league_key VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @detail_endpoint VARCHAR(100)

	SET @detail_endpoint = '/Event.svc/matchup/mma/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR)

	SELECT @league_key = l.league_key, @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
		   @start_date_time_EST = start_date_time, @ribbon = event_name
	  FROM dbo.SMG_Solo_Events AS e
	 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = @league_name AND l.league_key = e.league_key AND l.season_key = e.season_key
	 WHERE event_key = CAST(@eventId AS VARCHAR)

    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	SET @game_status = CASE	WHEN @event_status = 'pre-event' THEN CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
							WHEN @event_status = 'post-event' THEN 'Completed'
							ELSE UPPER(LEFT(@event_status, 1)) + RIGHT(@event_status, LEN(@event_status) - 1)
						END

    SELECT
	(
        SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
               @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @game_status AS game_status,
               @detail_endpoint AS detail_endpoint, @league_name AS league_name
           FOR XML RAW('brief'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
