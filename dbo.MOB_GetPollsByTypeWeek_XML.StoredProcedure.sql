USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetPollsByTypeWeek_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MOB_GetPollsByTypeWeek_XML]
	@leagueName VARCHAR(100),
	@type       VARCHAR(100),
	@week       INT
AS
--=============================================
-- Author: John Lin
-- Create date: 01/08/2014
-- Description: get polls for mobile by type and week
-- Update:	    07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @season_key INT

    SELECT TOP 1 @season_key = season_key
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @leagueName
     ORDER BY poll_date DESC

    EXEC dbo.MOB_GetPollsByTypeYearWeek_XML @leagueName, @type, @season_key, @week
	
END


GO
