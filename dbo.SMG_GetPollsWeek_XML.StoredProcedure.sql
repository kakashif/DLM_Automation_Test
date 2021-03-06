USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPollsWeek_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPollsWeek_XML]
	@leagueName VARCHAR(100),
	@pollName VARCHAR(100),
	@pollDate DATE
AS
--=============================================
-- Author:		ikenticus
-- Create date: 06/05/2014
-- Description: get polls week from date and league
-- Update:		07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    -- Unsupported league
    IF (@leagueName NOT IN (
		SELECT league_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 GROUP BY league_key
	))
    BEGIN
        RETURN
    END

	SELECT
	(
			SELECT TOP 1 week, league_key, season_key, fixture_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE poll_name = @pollName AND poll_date = @pollDate AND league_key = @leagueName
		   FOR XML RAW('poll'), TYPE
	)
	FOR XML RAW('root'), TYPE

END


GO
