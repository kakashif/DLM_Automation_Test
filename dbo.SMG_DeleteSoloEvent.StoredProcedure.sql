USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteSoloEvent]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteSoloEvent]
    @leagueKey VARCHAR(100),
	@seasonKey INT,
	@eventKey VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 11/04/2014
-- Description:	Delete Solo Events by specific parameters
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsDB.dbo.SMG_Solo_Events
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND event_key = @eventKey

END


GO
