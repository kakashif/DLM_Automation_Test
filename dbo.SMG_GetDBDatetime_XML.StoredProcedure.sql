USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetDBDatetime_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetDBDatetime_XML]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 01/20/2014
-- Description:	get db date time
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT 'SportsDB' AS [db_name], GETDATE() AS db_datetime
	FOR XML RAW('root'), TYPE

	SET NOCOUNT OFF;
END 



GO
