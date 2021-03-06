USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Transient_Baseball]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Transient_Baseball](
	[event_key] [varchar](100) NOT NULL,
	[batter_key] [varchar](100) NOT NULL,
	[pitcher_key] [varchar](100) NOT NULL,
	[sequence] [int] NOT NULL,
	[pitch_type] [varchar](100) NOT NULL,
	[velocity] [int] NOT NULL,
	[location_x] [varchar](10) NOT NULL,
	[location_y] [varchar](10) NOT NULL,
	[balls] [int] NOT NULL,
	[strikes] [int] NOT NULL,
	[umpire_call] [varchar](100) NULL,
 CONSTRAINT [PK__SMG_Tran__753F3625303B90E3] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[batter_key] ASC,
	[sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
