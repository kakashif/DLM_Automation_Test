USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventCoverage_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventCoverage_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/10/2014
-- Description: get addional event detail by event status
-- Update: 07/17/2014 - John Lin - update matchup logic
--         09/10/2014 - ikenticus - fixing incorrect column_type for recap
--         09/12/2014 - John Lin - check event status for which coverage to return
--         09/19/2014 - ikenticus: adding EPL/Champions
--         04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys
--         04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--         05/16/2015 - ikenticus: adjusting for world cup
--         05/19/2015 - ikenticus: adding coverage extraction for stats
--         06/23/2015 - John Lin - STATS migration
--		   06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--		   08/26/2015 - ikenticus - ingesting SDI coverage as HTML instead of XML
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
    DECLARE @site_name VARCHAR(100)
       
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @site_name = site_name
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @site_name = site_name
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    DECLARE @coverage VARCHAR(MAX)


	IF (@event_status IN ('pre-event'))
	BEGIN
		SELECT @coverage = value
		  FROM dbo.SMG_Scores
		 WHERE event_key = @event_key AND column_type = 'pre-event-coverage'
	END
	ELSE
	BEGIN
		SELECT @coverage = value
		  FROM dbo.SMG_Scores
		 WHERE event_key = @event_key AND column_type = 'post-event-coverage'
	END

    IF (@coverage IS NULL)
    BEGIN
        SET @coverage = ''
    END

    SELECT @coverage AS coverage, @site_name AS venue
       FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
