USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesByDateFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[DES_GetSchedulesByDateFilter_XML]
   @year   INT,
   @month  INT,
   @day    INT,
   @filter VARCHAR(50)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get schedules for ncaab for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.DES_GetSchedules_XML 'ncaab', NULL, NULL, NULL, @start_date, @filter

END

GO
