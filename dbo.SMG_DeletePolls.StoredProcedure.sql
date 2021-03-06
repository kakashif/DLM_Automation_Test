USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeletePolls]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeletePolls]
    @leagueKey VARCHAR(100),
	@fixtureKey VARCHAR(100),
	@pollDate DATE
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 10/13/2014
-- Description:	Delete Polls by specific parameters - safe to do once polls are updated via ingestor
-- Update:		12/01/2014 - ikenticus - adding ballots delete logic
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_Polls_Info
	 WHERE league_key = @leagueKey AND fixture_key = @fixtureKey AND poll_date = @pollDate

	DELETE FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueKey AND fixture_key = @fixtureKey AND poll_date = @pollDate

	DELETE FROM SportsEditDB.dbo.SMG_Polls_Votes
	 WHERE league_key = @leagueKey AND poll_date = @pollDate

END


GO
