USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Plays_Info]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Plays_Info](
	[league_key] [varchar](100) NULL,
	[event_key] [varchar](100) NOT NULL,
	[sequence_number] [int] NOT NULL,
	[play_type] [varchar](100) NOT NULL,
	[column] [varchar](100) NOT NULL,
	[value] [varchar](max) NOT NULL,
 CONSTRAINT [PK__SMG_Play__29A4FC757016EA2D] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[sequence_number] ASC,
	[play_type] ASC,
	[column] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
