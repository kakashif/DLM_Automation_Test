USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesByYearWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetSchedulesByYearWeek_XML]
	@leagueName VARCHAR(100),
	@year INT,
	@week VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	05/20/2015
-- Description:	get schedules for euro soccer for desktop
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetSchedules_XML @leagueName, @year, NULL, @week, NULL, NULL

END

GO
