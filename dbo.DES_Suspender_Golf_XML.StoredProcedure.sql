USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Suspender_Golf_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_Suspender_Golf_XML]
    @seasonKey INT,
    @eventKey VARCHAR(100)
AS
-- ================================================================================================
-- Author: John Lin
-- Create date: 07/16/2013
-- Description:	golf suspender via feed
-- Update:      07/21/2015 - ikenticus: refactored to use SMG_Solo_Leaders like Briefs
--				10/08/2015 - ikenticus: adjusted output for the Golf cups
-- ================================================================================================
BEGIN

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('pga-tour')
    DECLARE @event_name VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @event_format VARCHAR(100) = 'fedex'

    SELECT @event_name = event_name, @event_status = event_status
      FROM dbo.SMG_Solo_Events
     WHERE league_key = @league_key AND event_key = @eventKey
 

	DECLARE @stats TABLE (
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Leaders
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @eventKey

	DECLARE @event_type VARCHAR(100)

	SELECT @event_type = value
	  FROM @stats
     WHERE player_name = 'scoring-system'

	DECLARE @round INT

	SELECT @round = MAX([round])
	  FROM @stats
	 WHERE [round] IS NOT NULL

    IF (@event_status = 'mid-event')
    BEGIN
        SET @event_name = @event_name + ' Round ' + CAST(@round AS VARCHAR)
    END


	DECLARE @leaders TABLE (
		player			VARCHAR(100),
		player_name		VARCHAR(100),
		total			VARCHAR(100),
		position_event	VARCHAR(100),
		priority		INT
	)

	IF (@event_type IN ('presidents-cup', 'ryder-cup'))
	BEGIN
		INSERT INTO @leaders (player_name, total, position_event, priority)
		SELECT p.player_name, [score-total], [position-event], [rank]
		  FROM (SELECT player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([score-total], [position-event], [rank])) AS p

		UPDATE @leaders
		   SET player = player_name
	END
	ELSE
	BEGIN
		INSERT INTO @leaders (player_name, total, position_event, priority)
		SELECT p.player_name, [total], [position-event], [rank]
		  FROM (SELECT player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([total], [position-event], [rank])) AS p

		UPDATE @leaders
		   SET player = position_event + ' ' + player_name
	END

	DELETE @leaders
	 WHERE priority IS NULL


    DECLARE @links TABLE
    (
        link_head VARCHAR(100),
        link_href VARCHAR(100),
        link_target VARCHAR(100),
        link_text VARCHAR(100)        
    )

    INSERT INTO @links (link_head, link_href, link_target, link_text)
    VALUES ('GOLF', 'http://www.pgatour.com/leaderboard.html/?cid=USAT_top5LB', '_blank', 'Leaderboard')


    SELECT
	(
	    SELECT link_head AS '@link_head', link_href AS '@link_href', link_target AS '@link_target', link_text AS '@link_text'
		  FROM @links
		   FOR XML PATH('link'), TYPE	
    ),    
	(
	    SELECT @event_name AS '@round', @event_format AS '@format'
		   FOR XML PATH('tour'), TYPE	
    ),    
	(
	    SELECT player AS '@player', total AS '@points', priority AS '@pos'
		  FROM @leaders
		 ORDER BY priority ASC
		   FOR XML PATH('players'), TYPE	
    )
    FOR XML PATH('root')

END




GO
