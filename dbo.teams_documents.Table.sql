USE [SportsDB]
GO
/****** Object:  Table [dbo].[teams_documents]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[teams_documents](
	[team_id] [int] NOT NULL,
	[document_id] [int] NOT NULL,
 CONSTRAINT [PK_teams_documents] PRIMARY KEY CLUSTERED 
(
	[team_id] ASC,
	[document_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
