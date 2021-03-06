USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_DeleteTeamRecord]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_DeleteTeamRecord]
    @teamKey VARCHAR(100),
	@eventsPlayed INT,
	@dateTime VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 01/05/2015
-- Description:	Delete Team Record by specific team_key + events_played + date_time
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DELETE FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE team_key = @teamKey AND events_played = @eventsPlayed AND CAST(date_time_EST AS DATE) = @dateTime

END


GO
