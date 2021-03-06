USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeletePollsSurvey_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeletePollsSurvey_XML]
    @leagueName VARCHAR(100),
	@seasonKey INT,
	@week INT
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 07/23/2014
-- Description:	Delete Polls Survey (currently for Fan Poll)
-- Update:		07/30/2014 - ikenticus: forgot to restrict delete to league_key, also delete null weeks
--				07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
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

	DECLARE @fixture_key VARCHAR(100) = 'smg-usatfan'

	DELETE FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName AND fixture_key = @fixture_key AND season_key = @seasonKey AND week = @week

	-- Also delete any NULL weeks for cleanup purposes
	DELETE FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName AND fixture_key = @fixture_key AND season_key = @seasonKey AND week IS NULL

END


GO
