USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesFilterByYear_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[DES_GetSchedulesFilterByYear_XML]
   @year INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/18/2014
  -- Description: get schedules filter for NCAAF for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetSchedulesFilterByYearWeekFilter_XML @year, 'bowls', 'div1.a'

END

GO
