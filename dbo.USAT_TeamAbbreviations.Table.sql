USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_TeamAbbreviations]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_TeamAbbreviations](
	[team_id] [int] NOT NULL,
	[Abbreviation] [varchar](50) NULL,
 CONSTRAINT [PK_USAT_TeamAbbreviations_1] PRIMARY KEY CLUSTERED 
(
	[team_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
