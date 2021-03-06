USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetFiltersByYearWeek_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetFiltersByYearWeek_XML]
   @page VARCHAR(100),
   @seasonKey INT,
   @week VARCHAR(100),
   @filter	VARCHAR(100) = ''
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 05/01/2013
  -- Description: get filter for NCAAF
  -- Update: 06/04/2013 - John Lin - rename filter procedure
  --         06/05/2013 - John Lin - VARCHAR defaults to empty
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    EXEC dbo.SMG_GetScoreScheduleFilters_XML 'l.ncaa.org.mfoot', @page, @seasonKey, '', @week, NULL, @filter

END


GO
