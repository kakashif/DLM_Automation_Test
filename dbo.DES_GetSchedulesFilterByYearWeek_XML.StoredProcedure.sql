USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesFilterByYearWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetSchedulesFilterByYearWeek_XML]
	@leagueName VARCHAR(100),
	@year INT,
	@week VARCHAR(100)
AS
--=============================================
-- Author:	  John Lin
-- Create date: 03/18/2014
-- Description: get schedules filter for euro soccer for desktop
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresFilterByYearWeek_XML @leagueName, @year, @week, 'schedules'

END

GO
