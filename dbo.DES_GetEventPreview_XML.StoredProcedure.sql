USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventPreview_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventPreview_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/24/2014
-- Description:	get event preview for desktop
-- Update:		03/07/2014 - ikenticus: altering preview to query node
--              04/22/2014 - thlam: Adding the timestamp for preview
-- 				06/10/2015 - ikenticus: refactor to handle STATS preview
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--				08/26/2015 - ikenticus - ingesting SDI coverage as HTML instead of XML
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @coverage VARCHAR(MAX)
	DECLARE @date_time VARCHAR(100)

    SELECT @event_key = event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key, @event_key = event_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END
    
	SELECT @coverage = value, @date_time = date_time
	  FROM SportsDB.dbo.SMG_Scores
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key AND column_type = 'pre-event-coverage'


    SELECT
	(
	    SELECT ISNULL(@coverage, '') AS coverage
	       FOR XML PATH(''), TYPE
    ),
	(
	    SELECT @date_time
	       FOR XML PATH('updated_date'), TYPE
	)
    FOR XML PATH(''), ROOT('root')
    	    
    SET NOCOUNT OFF;
END

GO
