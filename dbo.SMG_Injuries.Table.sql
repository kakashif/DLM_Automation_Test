USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Injuries]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Injuries](
	[feed_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[injury_date] [date] NULL,
	[injury_type] [varchar](100) NULL,
	[injury_details] [varchar](max) NULL,
	[injury_class] [varchar](100) NULL,
	[injury_side] [varchar](100) NULL,
	[comment] [varchar](max) NULL,
	[date_time] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SMG_Injuries] PRIMARY KEY CLUSTERED 
(
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
