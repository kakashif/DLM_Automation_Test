USE [SportsDB]
GO
/****** Object:  Table [dbo].[UGC_Brackets]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UGC_Brackets](
	[bracket_key] [varchar](100) NOT NULL,
	[match_id] [int] NOT NULL,
	[team_a] [varchar](100) NULL,
	[team_b] [varchar](100) NULL,
	[team_a_points] [int] NULL,
	[team_b_points] [int] NULL,
	[date_time] [datetime] NOT NULL,
 CONSTRAINT [PK_UGC_Brackets] PRIMARY KEY CLUSTERED 
(
	[bracket_key] ASC,
	[match_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
