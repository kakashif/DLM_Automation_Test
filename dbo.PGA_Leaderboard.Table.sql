USE [SportsDB]
GO
/****** Object:  Table [dbo].[PGA_Leaderboard]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PGA_Leaderboard](
	[tour_code] [varchar](2) NOT NULL,
	[tour_id] [int] NOT NULL,
	[player_id] [int] NOT NULL,
	[date_time] [datetime] NOT NULL,
	[fname] [varchar](200) NULL,
	[lname] [varchar](200) NULL,
	[cur_pos] [varchar](32) NULL,
	[cur_par_rel] [varchar](32) NULL,
	[thru] [varchar](32) NULL,
	[tourn_par_rel] [varchar](32) NULL,
	[sort] [int] NULL,
	[fedex_rank] [varchar](10) NULL,
 CONSTRAINT [PK_PGA_Leaderboard] PRIMARY KEY CLUSTERED 
(
	[tour_code] ASC,
	[tour_id] ASC,
	[player_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
