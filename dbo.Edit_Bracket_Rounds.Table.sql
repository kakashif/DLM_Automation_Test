USE [SportsDB]
GO
/****** Object:  Table [dbo].[Edit_Bracket_Rounds]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Edit_Bracket_Rounds](
	[league_name] [varchar](100) NOT NULL,
	[match_id] [int] NOT NULL,
	[round_order] [int] NOT NULL,
	[round_id] [varchar](100) NOT NULL,
	[round_display] [varchar](100) NOT NULL,
	[round_points] [int] NULL,
	[match_finish] [int] NULL,
 CONSTRAINT [PK_Edit_Bracket_Rounds] PRIMARY KEY CLUSTERED 
(
	[league_name] ASC,
	[match_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
