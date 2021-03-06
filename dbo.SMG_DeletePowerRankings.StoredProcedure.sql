USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeletePowerRankings]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeletePowerRankings]  
    @leagueKey VARCHAR(100),
	@weekBegin DATE
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 12/19/2014
-- Description:	Delete PowerRankings by specific league_key + week_begin
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueKey AND week_begin = @weekBegin
END


GO
