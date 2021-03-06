USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[EXT_GetEventPreview_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[EXT_GetEventPreview_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 05/02/2014
-- Description:	get event preview for external, duplicating from DES version
-- Update: 06/23/2015 - John Lin - STATS migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @coverage VARCHAR(MAX)
	DECLARE @body XML
	DECLARE @date_time VARCHAR(100)

    SELECT TOP 1 @event_key = event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
    
    SELECT @body = value, @date_time = date_time
      FROM SportsDB.dbo.SMG_Scores
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key AND column_type = 'pre-event-coverage'

	SELECT @coverage = CAST(node.query('p') AS VARCHAR(MAX)) + CAST(node.query('note/body.content/*') AS VARCHAR(MAX))
	  FROM @body.nodes('//body/body.content') AS SMG(node)

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
