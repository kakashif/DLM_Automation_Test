USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteBallots]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteBallots]
    @leagueKey VARCHAR(100),
	@pollDate DATE
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 01/13/2015
-- Description:	Delete Ballots by specific parameters
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_Polls_Votes
	 WHERE league_key = @leagueKey AND poll_date = @pollDate

END


GO
