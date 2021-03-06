USE [SportsDB]
GO
/****** Object:  View [dbo].[ViewContent_Inventory]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		John Titchener
-- Create date: 8/1/2012
-- Description:	Selects content inventory items.
-- =============================================

CREATE VIEW [dbo].[ViewContent_Inventory]
AS
SELECT	USAT_LS.asset_id
		, USAT_CI.source_id
		, USAT_CI.vendor_id
		, USAT_LS.update_date
		, USAT_LS.update_status
		, USAT_LS.TLC_Key
		, USAT_LS.page_url
FROM dbo.USAT_content_inventory AS USAT_CI  WITH (NOLOCK) 
	INNER JOIN dbo.USAT_lookup_source_x_asset AS USAT_LS  WITH (NOLOCK) 
ON USAT_CI.id = USAT_LS.source_ID;





GO
