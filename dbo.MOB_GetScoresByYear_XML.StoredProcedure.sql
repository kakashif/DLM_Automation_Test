USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScoresByYear_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetScoresByYear_XML]
   @year INT,
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/01/2013
  -- Description: get scores for NCAAF for mobile
  -- Update: 12/15/2014 - John Lin - add week
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.MOB_GetScoresByYearWeekFilter_XML @year, @week, NULL

END

GO
