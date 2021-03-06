USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_lookup_source_x_asset]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_lookup_source_x_asset](
	[TLC_Key] [varchar](100) NULL,
	[page_type_id] [int] NULL,
	[Asset_id] [int] NULL,
	[url] [varchar](200) NULL,
	[ssts] [varchar](200) NULL,
	[source_id] [int] NULL,
	[TLC_Id] [int] NULL,
	[TLC_Type] [char](1) NULL,
	[update_date] [datetime] NULL,
	[update_status] [varchar](250) NULL,
	[page_url] [varchar](255) NULL,
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
