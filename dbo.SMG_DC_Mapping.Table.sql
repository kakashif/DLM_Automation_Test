USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_DC_Mapping]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_DC_Mapping](
	[dc_id] [int] NOT NULL,
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NULL,
	[sub_season_type] [varchar](100) NULL,
	[fixture_key] [varchar](100) NOT NULL,
	[status] [varchar](100) NOT NULL,
	[upsert] [datetime] NOT NULL,
	[key] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_DC_mapping] PRIMARY KEY CLUSTERED 
(
	[dc_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
