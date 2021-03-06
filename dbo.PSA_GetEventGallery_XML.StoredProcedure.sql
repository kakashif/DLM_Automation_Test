USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventGallery_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventGallery_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	07/10/2014
-- Description:	get addional event detail by event status
-- Update:		07/17/2014 - John Lin - update matchup logic
-- 				09/19/2014 - ikenticus: adding EPL/Champions
--				09/25/2014 - ikenticus: adding gallery limit
--				11/17/2014 - ikenticus: adding gallery_keywords failover logic
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys 
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--				06/09/2015 - ikenticus: altering world cup gallery terms
--              06/23/2015 - John Lin - STATS migration
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @start_date_time_EST VARCHAR(100)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_name VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_name VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @start_date_time_EST = start_date_time_EST, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @start_date_time_EST = start_date_time_EST, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

/* comment out until 1.0.3 jameson

    IF (@event_status = 'pre-event')
    BEGIN
	    SELECT '' AS gallery
           FOR XML PATH(''), ROOT('root')

        RETURN
    END
    
*/

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw', 'epl', 'champions', 'natl', 'wwc'))
    BEGIN
        SELECT @away_name = team_first
          FROM dbo.SMG_Teams 
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_first
          FROM dbo.SMG_Teams 
         WHERE season_key = @seasonKey AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
   
    -- GALLERY (SportsImages searchAPI)
   	DECLARE @gallery_terms VARCHAR(100) = @leagueName
    DECLARE @gallery_keywords VARCHAR(100) = @away_name + ' ' + @home_name
    DECLARE @gallery_start_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST)
    DECLARE	@gallery_end_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST) + 21600
   	DECLARE @gallery_limit INT = 100

	IF (@away_name IS NULL)
	BEGIN
		SET @gallery_keywords = @home_name
	END

	IF (@home_name IS NULL)
	BEGIN
		SET @gallery_keywords = @away_name
	END

	IF (@gallery_keywords IS NULL)
	BEGIN
		SET @gallery_keywords = @event_key
	END

    IF (@leagueName = 'ncaaf')
    BEGIN
	    SET @gallery_terms = 'NCAA Football'
   	END
    ELSE IF (@leagueName ='ncaab')
   	BEGIN
    	SET @gallery_terms = 'NCAA Basketball'
    END

	IF (@leagueName IN ('natl', 'wwc'))
	BEGIN
		SET @gallery_terms = 'soccer'
	END

    SELECT
    (
	    SELECT @gallery_terms AS terms,
		       @gallery_keywords AS keywords,
    	       @gallery_start_date AS [start_date],
    	 	   @gallery_end_date AS end_date,
    	 	   @gallery_limit AS limit
           FOR XML RAW('gallery'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
