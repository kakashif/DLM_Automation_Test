USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[API_GetEventDatesSolo_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[API_GetEventDatesSolo_XML] 
    @leagueName VARCHAR(100),
	@leagueId VARCHAR(100)
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 07/16/2014
-- Description: get event dates for solo
-- Update:		10/02/2014 - ikenticus - adding MMA
--				03/26/2015 - ikenticus - adding motor
--				07/16/2015 - ikenticus - using league_key function
--test
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('golf', 'mma', 'motor', 'nascar', 'tennis'))
    BEGIN
        RETURN
    END

    DECLARE @yesterday DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    DECLARE @concat VARCHAR(MAX)

    DECLARE @dates TABLE
    (
        [date] DATE,
        season_key INT,
		event_name VARCHAR(100)
    )

	DECLARE @valid_leagues TABLE (
		league_key	VARCHAR(100)
	)

	IF (@leagueName IN ('mma'))
	BEGIN
		INSERT INTO @valid_leagues (league_key) VALUES (@leagueName)
	END
	ELSE IF (@leagueId IS NULL OR @leagueID = '')
	BEGIN
		INSERT INTO @valid_leagues (league_key)
		SELECT league_key
		  FROM dbo.SMG_Solo_Leagues
		 WHERE league_name = @leagueName
		 GROUP BY league_key

		INSERT INTO @dates ([date], season_key, event_name)
		SELECT start_date_time, season_key, event_name
		  FROM dbo.SMG_Solo_Events
		 WHERE league_key IN (SELECT league_key FROM @valid_leagues)
		   AND (start_date_time > @yesterday OR end_date_time > @yesterday)
	END
	ELSE
	BEGIN
		DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)

		INSERT INTO @dates ([date], season_key, event_name)
		SELECT start_date_time, season_key, event_name
		  FROM dbo.SMG_Solo_Events
		 WHERE league_key = @league_key
		   AND (start_date_time > @yesterday OR end_date_time > @yesterday)
	END

	SELECT @concat = COALESCE(@concat + ',' + CAST([date] AS VARCHAR), CAST([date] AS VARCHAR))
	  FROM @dates
	 GROUP BY [date]

	 
    SELECT
	(
        SELECT @concat AS dates
           FOR XML PATH(''), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
