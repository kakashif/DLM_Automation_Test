USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesFilterByDateFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_GetSchedulesFilterByDateFilter_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT,
   @filter     VARCHAR(50) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/18/2014
  -- Description: get schedules filter for daily sport for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresFilterByDateFilter_XML @leagueName, @year, @month, @day, @filter, 'schedules'

END

GO
