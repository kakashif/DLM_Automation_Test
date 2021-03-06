USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventDetailSolo_MMA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventDetailSolo_MMA_XML] 
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 10/02/2014
-- Description: get event detail for MMA
-- Update:		10/09/2014 - ikenticus: adjusting to new leagues from ingestor
--				10/28/2014 - ikenticus: swapping gallery terms and keywords, removing title fighters
--				11/06/2014 - ikenticus: HTMLencoding ampersand
--				11/07/2014 - ikenticus: alter to only encode unencoded ampersands
--				11/14/2014 - ikenticus: only extract @ribbon left if colon exists in @ribbon
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--				03/04/2015 - ikenticus - fixing other event_status
--				06/30/2015 - ikenticus - using MMA event id as event_key
--				07/17/2016 - ikenticus: optimizing by replacing table calls with temp table
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
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)

    DECLARE @preview VARCHAR(MAX)
    DECLARE @recap VARCHAR(MAX)
    DECLARE @body XML
    DECLARE @coverage VARCHAR(MAX)

	SELECT @league_key = l.league_key, @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
		   @start_date_time_EST = start_date_time, @ribbon = event_name, @preview = pre_event_coverage, @recap = post_event_coverage
	  FROM dbo.SMG_Solo_Events AS e
	 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = @league_name AND l.league_key = e.league_key AND l.season_key = e.season_key
	 WHERE event_key = CAST(@eventId AS VARCHAR)

	--SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	SET @game_status = CASE	WHEN @event_status = 'pre-event' THEN CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
							WHEN @event_status = 'post-event' THEN 'Completed'
							WHEN @event_status = 'mid-event' THEN 'In Progress'
							ELSE UPPER(LEFT(@event_status, 1)) + RIGHT(@event_status, LEN(@event_status) - 1)
						END

	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_terms VARCHAR(100) = @ribbon
	DECLARE @gallery_keywords VARCHAR(100) = 'mma'
	DECLARE @gallery_start_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST)
	DECLARE	@gallery_end_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST) + 86400
   	DECLARE @gallery_limit INT = 100

	IF (CHARINDEX(':', @ribbon) > 0)
	BEGIN
		SET @gallery_terms = LEFT(@ribbon, CHARINDEX(':', @ribbon) - 1)
	END

	IF (@event_status = 'pre-event')
	BEGIN
		SELECT @body = REPLACE(@preview, '& ', '&amp; ')

		SELECT @coverage = CAST(node.query('.') AS VARCHAR(MAX))
		  FROM @body.nodes('.') AS SMG(node)
	END
	ELSE
	BEGIN
		SELECT @body = REPLACE(@recap, '& ', '&amp; ')

		SELECT @coverage = CAST(node.query('.') AS VARCHAR(MAX))
		  FROM @body.nodes('.') AS SMG(node)
	END


    SELECT
	(
        SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
               @ribbon AS ribbon, @game_status AS game_status, @coverage AS coverage
           FOR XML RAW('detail'), TYPE
    ),
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
