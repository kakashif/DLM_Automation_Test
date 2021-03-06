USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[HUB_fn_Leaderboard_Height]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[HUB_fn_Leaderboard_Height] (
	@url VARCHAR(200)
)
RETURNS INT
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 09/30/2015
-- Description:	return calculated height of leaderboard widget
-- =============================================
BEGIN

	DECLARE @height INT = 240
	DECLARE @event_id VARCHAR(100)
	DECLARE @event_key VARCHAR(100)
	DECLARE @league_id VARCHAR(100)
	DECLARE @league_key VARCHAR(100)
	DECLARE @season_path VARCHAR(100)
	DECLARE @season_key INT
	DECLARE @leaders INT = 5
	

	IF (@url LIKE '%/')
	BEGIN
		SET @url = LEFT(@url, LEN(@url) - 1)
	END

	SET @event_id = RIGHT(@url, CHARINDEX('/', REVERSE(@url)) - 1)
	
	IF (ISNUMERIC(@event_id) = 1)
	BEGIN
		SET @url = REPLACE(@url, '/' + @event_id, '')
		SET @league_id = RIGHT(@url, CHARINDEX('/', REVERSE(@url)) - 1)

		SET @url = REPLACE(@url, '/' + @league_id, '')
		SET @season_path = RIGHT(@url, CHARINDEX('/', REVERSE(@url)) - 1)

		IF (ISNUMERIC(@season_path) = 1)
		BEGIN
			SET @season_key = CAST(@season_path AS INT)
			SET @league_key = dbo.SMG_fnGetLeagueKey(@league_id)

			SELECT @event_key = event_key
			  FROM dbo.SMG_Solo_Events
			 WHERE league_key = @league_key AND season_key = @season_key AND event_key LIKE '%:' + CAST(@event_id AS VARCHAR)	

			SELECT @leaders = value
			  FROM dbo.SMG_Solo_Leaders
			 WHERE league_key = @league_key AND season_key = @season_key AND event_key = @event_key
			   AND player_name = 'leaderboard-info' AND [column] = 'top5'

			-- if SMG_Solo_Leaders does not have the Top5 count, grab the Top3 like PSA
			IF (@leaders IS NULL)
			BEGIN
				SELECT @leaders = COUNT(*)
				  FROM dbo.SMG_Solo_Leaders
				 WHERE league_key = @league_key AND season_key = @season_key AND event_key = @event_key
				   AND [column] = 'position-event'
			END

			SET @height = 115 + (25 * @leaders)
		END
	END

	
	RETURN @height

END

GO
