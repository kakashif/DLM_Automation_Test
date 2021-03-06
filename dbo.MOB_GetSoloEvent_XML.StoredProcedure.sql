USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetSoloEvent_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetSoloEvent_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100),
	@eventId INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	11/21/2014
-- Description: get Event info for Solo Sports
-- Update:		02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/12/2015 - ikenticus: using function for current source league_key
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	-- get league_key/event_key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
	DECLARE @event_name VARCHAR(100)

	SELECT @event_key = event_key, @event_name = event_name
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)


    DECLARE @info TABLE (
        date_range VARCHAR(100),
		start_date_time DATETIME,
		event_status VARCHAR(100),
        event_key VARCHAR(100),
        event_name VARCHAR(100),
        site_name VARCHAR(100),
        site_city VARCHAR(100),
        site_state VARCHAR(100),
        site_count VARCHAR(100),
        site_size VARCHAR(100),
        site_size_unit VARCHAR(100),
        site_surface VARCHAR(100),
        purse VARCHAR(100),
        winner VARCHAR(100),
		link VARCHAR(100),
		ribbon VARCHAR(100)
    )

	INSERT INTO @info
	SELECT 
		(CASE
			WHEN end_date_time IS NULL THEN CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(11))
			ELSE (CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(6)) + ' - ' + CAST(CONVERT(DATETIME, end_date_time) AS VARCHAR(6)))
			END) AS date_range,
		start_date_time,
		ISNULL(event_status, CASE WHEN start_date_time < CURRENT_TIMESTAMP THEN 'post-event' ELSE 'pre-event' END) AS event_status,
		event_key,
		REPLACE(event_name, '&amp', ' & '),
		site_name,
		ISNULL(NULLIF(site_city, ''), '--') AS site_city,
		ISNULL(NULLIF(site_state, ''), '--') AS site_state,
		ISNULL(NULLIF(CAST(site_count AS VARCHAR(100)), '0'), '--') AS site_count,
		ISNULL(NULLIF(site_size, ''), '--') AS site_size,
		ISNULL(site_size_unit, '--') AS site_size_unit,
		ISNULL(site_surface, '--') AS site_surface,
		ISNULL(NULLIF(REPLACE(purse, '$', ''), ''), '--') AS purse,
		ISNULL(winner, '--') AS winner,
		NULL, '0'
	FROM dbo.SMG_Solo_Events
	WHERE season_key = @seasonKey AND league_key = @league_key AND event_key = @event_key

	UPDATE @info
	   SET purse = '$' + purse
	 WHERE purse <> '--'

	UPDATE @info
	   SET site_surface = 'hardcourt'
	 WHERE site_surface = 'asphalt'


	-- output XML
	SELECT date_range, start_date_time, event_status, event_name, site_name, site_city, site_state,
		   site_count, site_size, site_size_unit, site_surface,
		   purse, winner, link
	  FROM @info
	   FOR XML RAW('root'), TYPE
	
END

GO
