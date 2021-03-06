USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetPollsByType_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetPollsByType_XML]
    @leagueName VARCHAR(100),
    @type       VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get polls for mobile by type
  -- Update: 01/17/2014 - John Lin - filter by poll type
  --		 07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @week INT

    SELECT TOP 1 @week = [week]
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @leagueName AND fixture_key = @type
     ORDER BY poll_date DESC

    EXEC dbo.MOB_GetPollsByTypeWeek_XML @leagueName, @type, @week
    
    SET NOCOUNT OFF
END 

GO
