USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteSchedule]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteSchedule]
    @leagueKey VARCHAR(100),
	@seasonKey INT,
	@eventKey VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 01/06/2015
-- Description:	Delete Schedule event by specific parameters
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsDB.dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND event_key = @eventKey

END


GO
