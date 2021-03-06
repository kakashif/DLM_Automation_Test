USE [SportsDB]
GO
/****** Object:  Table [dbo].[USCP_football_drives]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USCP_football_drives](
	[event_key] [varchar](100) NOT NULL,
	[drive_number] [int] NOT NULL,
	[team_key] [varchar](100) NULL,
	[scoring_drive] [int] NULL,
	[primary_scoring_type] [varchar](100) NULL,
	[starting_yard_line] [int] NULL,
	[starting_field_key] [varchar](100) NULL,
	[starting_position] [int] NULL,
	[ending_yard_line] [int] NULL,
	[ending_field_key] [varchar](100) NULL,
	[ending_position] [int] NULL,
	[total_yards] [int] NULL,
	[time_of_possession] [varchar](100) NULL,
	[number_of_plays] [int] NULL,
 CONSTRAINT [PK_SMG_football_drives] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[drive_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
